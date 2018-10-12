defmodule Server.Application do
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
      # Starts a worker by calling: Server.Worker.start_link(arg)
      # {Server.Worker, arg},

      worker(PidCache, [
        [{:delegate, Application.fetch_env!(:server, :root_target), 0}],
        [name: PidCache]
      ]),
      {
        Cache,
        name: Cache
      },
      worker(Server.StreamServer.TcpServer, [
        [port: Application.fetch_env!(:server, :tcp_port)],
      ]),


      {
        Plug.Adapters.Cowboy2,
        scheme: :http,
        plug: Server.Router,
        options: [
          port: Application.fetch_env!(:server, :web_port),
          dispatch: Server.Dispatcher.dispatch
        ]
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Server.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
