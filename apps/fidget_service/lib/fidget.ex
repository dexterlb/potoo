defmodule FidgetService.Fidget do
  use GenServer

  def start_link(registry, opts \\ []) do
    GenServer.start_link(__MODULE__, registry, opts)
  end

  def init(registry) do
    result = Mesh.direct_call(registry, ["register"], %{
        "name" => "fidget_service", 
        "delegate" => %Mesh.Contract.Delegate{destination: self()}
    })

    case result do
      :ok -> {:ok, nil}
      err -> err
    end
  end

  @contract %{
    "description" => "A service with many calls which do nothing"
  }

  def handle_call(:contract, _from, state) do
    {:reply, @contract, state}
  end

  def handle_call(:subscribe_contract, _from, state) do
    {:ok, chan} = Mesh.Channel.start_link()
    {:reply, chan, state}
  end
end