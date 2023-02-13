defmodule Protohacker.EchoServer do
  use GenServer
  require Logger

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
    exit_on_close: false #without this option you can't write to closed socket
  ]

    case :gen_tcp.listen(5000, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting echo server on port 5000.")
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
    case recv_until_closed(socket, _buffer = "", _buffered_size = 0) do
      #send write to socket
      {:ok, data} -> :gen_tcp.send(socket, data)
      # #{} is interpolation
      {:error, reason} -> Logger.error("Failed to recieve data: #{inspect(reason)}")

    end

    :gen_tcp.close(socket)
  end

  @limit _10_kb = 1024 * 100
  defp recv_until_closed(socket, buffer, buffered_size) do
    #recv reads data in active false mode
    # 0 means read all available bytes
    # 10_000 timeout in milisecs
    case :gen_tcp.recv(socket, 0, 10_000) do
      # iodata is a tree-like erlang data structure
      # allows us to avoid memory allocation bc multiple concatenation
      # see :gen_tcp.send() specs
      # Also https://hexdocs.pm/elixir/1.12/IO.html was helpful
      {:ok, data} when buffered_size + byte_size(data) > @limit -> {:error, :buffer_overflow}
      {:ok, data} -> recv_until_closed(socket, [buffer, data], buffered_size + byte_size(data))
      {:error, :closed} -> {:ok, buffer}
      {:error, reason} -> {:error, reason} #bubble up to our caller?
    end
  end
end

#For TCP -> listen socket: that's what you bind to a port on your machine
# To accept a connection TCP libraries provide "accept"
# When listen socket accepts a connection returns a peer socket.
# Listen can accept many sockets, peer sockets are always one-to-one
