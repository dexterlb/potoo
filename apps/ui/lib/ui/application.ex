defmodule Ui.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Mesh.ServerUtils.PidCache
  alias Mesh.Cache

  def start(_type, _args) do
    import Supervisor.Spec

    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Ui.Worker.start_link(arg)
      # {Ui.Worker, arg},

      worker(PidCache, [
        [{:delegate, Application.fetch_env!(:ui, :root_target), 0}],
        [name: PidCache]
      ]),
      worker(Cache, [
        [name: Cache]
      ]),
      worker(Ui.StreamServer.TcpServer, [
        [port: 4444],
      ]),


      {
        Plug.Adapters.Cowboy,
        scheme: :http,
        plug: Ui.Router,
        options: [
          port: 4040,
          dispatch: Ui.Dispatcher.dispatch
        ]
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ui.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
