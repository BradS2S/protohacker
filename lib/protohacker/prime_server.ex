defmodule Protohacker.PrimeServer do
  use GenServer

  require Logger


  # {"method": "isPrime", "number": 14}
  def start_link([] = _opts) do
    GenServer.start_link(__MODULE__, :no_state)
  end

  defstruct [:listen_socket, :supervisor]

@impl true #implementation of GenServer callback
def init(:no_state) do
  #creates supervisor
  {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)
  listen_options = [
    mode: :binary, # charlist by default
    active: false, # all actions on socket are explicit and blocking
    reuseaddr: true, #reuse same port number
    exit_on_close: false, #without this option you can't write to closed socket
    packet: :line, # https://www.erlang.org/doc/man/gen_tcp.html#type-option
                  # gen_tcp will only return one line at a time
    buffer: 1024 * 100 # original dbg showed buffer of 1460
                ]


    case :gen_tcp.listen(5002, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting prime server on port 5002.")
        state = %__MODULE__{listen_socket: listen_socket, supervisor: supervisor}

        #start accepting sockets async
        # :accept could be any term
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    case :gen_tcp.accept(state.listen_socket) do
      # one-to-one socket
      {:ok, socket} ->
        # spawns new child
        Task.Supervisor.start_child(state.supervisor, fn -> handle_connection(socket) end)
        {:noreply, state, {:continue, :accept}}
      # accept fails
      {:error, reason} ->
        {:stop, reason}
    end

  end

  #Helpers
  defp handle_connection(socket) do
    # Smoke test requires that the socket stay open until the client closes it
    case echo_lines_until_closed(socket) do
      #send write to socket
      :ok -> :ok
      # #{} is interpolation
      {:error, reason} -> Logger.error("Failed to recieve data: #{inspect(reason)}")

    end

    :gen_tcp.close(socket)
  end

  defp echo_lines_until_closed(socket) do
    case :gen_tcp.recv(socket, 0, 10_000) do
      # iodata is a tree-like erlang data structure
      # allows us to avoid memory allocation bc multiple concatenation
      # see :gen_tcp.send() specs
      # Also https://hexdocs.pm/elixir/1.12/IO.html was helpful
      {:ok, data} ->
        case Jason.decode(data) do
          {:ok, %{"method" => "isPrime", "number" => number}} when is_number(number) ->
            Logger.debug("Received valid request for numbers: #{number}")
            response = %{"method" => "isPrime", "prime" => prime?(number)}
            :gen_tcp.send(socket, [Jason.encode!(response), ?\n])
            echo_lines_until_closed(socket)

          other ->
            Logger.debug("Recieved invalid request: #{inspect(other)}.")
            :gen_tcp.send(socket, "malformed request\n") #when sending packet it is our responsibility to send correct header.
            {:error, :invalid_request}

        end

      {:error, :closed} -> :ok
      {:error, reason} -> {:error, reason} #bubble up to our caller?
    end
  end

    defp prime?(number) when is_float(number), do: false
    defp prime?(number) when number <= 1, do: false
    defp prime?(number) when number in [2, 3], do: true

    defp prime?(number) do
      not Enum.any?(2..trunc(:math.sqrt(number)), &(rem(number, &1) == 0))
    end

  end

#For TCP -> listen socket: that's what you bind to a port on your machine
# To accept a connection TCP libraries provide "accept"
# When listen socket accepts a connection returns a peer socket.
# Listen can accept many sockets, peer sockets are always one-to-one
