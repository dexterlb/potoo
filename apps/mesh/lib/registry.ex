defmodule Mesh.Registry
  use GenServer

  def init(static_data) do
    {:ok, {static_data, %{}}}
  end

  def handle_call(:contract, _from, state) do
    {:reply, contract(state), state}
  end

  def handle_call({"register", %{"name" => name, "delegate" => delegate}}, _from, {static_data, services}) do
    {:reply, :ok, {static_data, register(services, name, delegate)}}
  end

  defp register(services, name, delegate) do
    %{
      services |
        name => delegate
    }
  end

  defp contract({static_data, services}) do
    %{
      static_data |
        "register" => %Mesh.Contract.Function{
          name: "register",
          args: %{
            "name" => %{
              "type" => :string,
              "description" => "Unique name for the service"
            },
            "delegate" => %{
              "type" => :delegate,
            }
          },
          retval: %{
            "type" => :maybe_ok
          },
          data: %{
            "description" => "Registers a new service into the registry"
          }
        },
        "services" => services
    }
  end
end