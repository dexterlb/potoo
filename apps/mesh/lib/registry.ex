defmodule Mesh.Registry do
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
    Map.put(services, name, delegate)
  end

  defp contract({static_data, services}) do
    Map.merge(
      static_data,
      %{
        "register" => %Mesh.Contract.Function{
          name: "register",
          argument: {:struct, %{
            "name" => {:type,
              :string,
              %{"description" => "Unique name for the service"}
            },
            "delegate" => :delegate
          }},
          retval: {:union, 
            {:literal, :ok}, 
            {:struct, {{:literal, :fail}, :string}}
          },
          data: %{
            "description" => "Registers a new service into the registry"
          }
        },
        "services" => services
      }
    )
  end
end