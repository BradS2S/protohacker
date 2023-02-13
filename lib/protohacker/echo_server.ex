defmodule Protohacker.EchoServer do
  use GenServer
  require Logger

  def start_link([] = _opts) do
    GenServer.start_link(__MODULE__, :no_state)
  end

  defstruct [:listen_socket]

@impl true
def init(:no_state) do
    Logger.info("Starting echo server on port 5001.")

    listen_options = [
      mode: :binary,
      active: false,
      reuseaddr: true
    ]

    case :gen_tcp.listen(5001, listen_options) do
      {:ok, listen_socket} ->
        state = %__MODULE__{listen_socket: listen_socket}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end

    {:ok, %__MODULE__{}}

  end
end

#For TCP -> listen socket: that's what you bind to a port on your machine
# To accept a connection TCP libraries provide "accept"
# When listen socket accepts a connection returns a peer socket.
# Listen can accept many sockets, peer sockets are always one-to-one
