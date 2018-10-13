defmodule MqttMesh do
  use GenServer

  def start_link(contract, opts \\ []) do
    GenServer.start_link(__MODULE__, contract, opts)
  end

  def init(contract, opts \\ []) do
    IO.inspect(contract)

    {:ok, contract}
  end

  def mqtt(foo) do
    IO.inspect(foo)
    42
  end
end
