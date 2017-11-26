defmodule FidgetService.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Supervisor.Spec

  def start(_type, _args) do
    # List all child processes to be supervised
    true = Node.connect(Application.fetch_env!(:fidget, :registry_node))

    children = [
      # Starts a worker by calling: FidgetService.Worker.start_link(arg)
      # {FidgetService.Worker, arg},
      worker(FidgetService.Fidget, [Application.fetch_env!(:fidget, :registry), [name: FidgetService.Fidget]]),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FidgetService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
