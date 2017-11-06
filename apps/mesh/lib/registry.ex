defmodule Mesh.Registry do
  use GenServer

  def start_link(static_data, opts \\ []) do
    GenServer.start_link(__MODULE__, static_data, opts)
  end

  def init(static_data) do
    case Mesh.Channel.start_link() do
      {:ok, chan} ->
        {:ok, {static_data, %{}, chan}}
      err -> err
    end
  end

  def handle_call(:contract, _from, state) do
    {:reply, contract(state), state}
  end

  def handle_call(:subscribe_contract, _from, state = {_, _, contract_channel}) do
    {:reply, contract_channel, state}
  end

  def handle_call({"register", %{"name" => name, "delegate" => delegate}}, _from, {static_data, services, contract_channel}) do
    new_state = {static_data, register(services, name, delegate), contract_channel}
    Mesh.Channel.send_lazy(contract_channel, fn -> contract(new_state) end)
    {:reply, :ok, new_state}
  end

  defp register(services, name, delegate) do
    Map.put(services, name, delegate)
  end

  defp contract({static_data, services, _}) do
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