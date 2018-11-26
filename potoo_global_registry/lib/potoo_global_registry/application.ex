defmodule PotooGlobalRegistry.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  import Supervisor.Spec

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: PotooGlobalRegistry.Worker.start_link(arg)
      # {PotooGlobalRegistry.Worker, arg},
      worker(
        Potoo.Registry,
        [
          %{
            "description" => "The global registry"
          },
          [name: Application.get_env(:potoo_global_registry, :name, :potoo_global_registry)]
        ]
      ),
    ] ++ if Application.get_env(:potoo_global_registry, :no_toys, false) do
      []
    else
      [
        worker(PotooGlobalRegistry.Hello, [:potoo_global_registry, [name: PotooGlobalRegistry.Hello]]),
        worker(PotooGlobalRegistry.Clock, [:potoo_global_registry, [name: PotooGlobalRegistry.Clock]]),
      ]
    end


    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_all, name: PotooGlobalRegistry.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
