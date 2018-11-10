defmodule PotooServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Potoo.ServerUtils.PidCache
  alias Potoo.Cache

  def start(_type, _args) do
    import Supervisor.Spec

    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: PotooServer.Worker.start_link(arg)
      # {PotooServer.Worker, arg},

      worker(PidCache, [
        [{:delegate, Application.fetch_env!(:server, :root_target), 0}],
        [name: PidCache]
      ]),
      {
        Cache,
        name: Cache
      },
      worker(PotooServer.StreamServer.TcpServer, [
        [port: Application.fetch_env!(:server, :tcp_port)],
      ]),


      {
        Plug.Cowboy,
        scheme: :http,
        plug: PotooServer.Router,
        options: [
          port: Application.fetch_env!(:server, :web_port),
          dispatch: PotooServer.Dispatcher.dispatch
        ]
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PotooServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
