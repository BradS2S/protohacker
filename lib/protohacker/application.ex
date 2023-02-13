defmodule Protohacker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Protohacker.EchoServer
      # Starts a worker by calling: Protohacker.Worker.start_link(arg)
      # {Protohacker.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Protohacker.Supervisor]

    #starts the supervision tree
    Supervisor.start_link(children, opts)
  end
end
