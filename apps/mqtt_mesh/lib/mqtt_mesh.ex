defmodule MqttMesh do
  use GenServer

  alias Mesh.Contract
  alias Mesh.Contract.Function
  alias Mesh.Contract.Delegate

  @type scheme
    :: Contract.value
    |  scheme_list
    |  scheme_map
    |  Function.t
    |  Delegate.t
    |  {:mqtt, mqtt_spec}

  @type scheme_list   :: [scheme]
  @type scheme_map    :: %{required(Contract.key) => scheme}

  @type mqtt_spec :: %{
    required(:topic) => String.t,
    :setter          => String.t | {String.t, String.t},
    :getter          => String.t | {String.t, String.t},
    :status          => String.t,
    :type            => Type.t,
  }


  def start_link(contract_scheme, opts \\ []) do
    GenServer.start_link(__MODULE__, contract_scheme, opts)
  end

  def init(contract_scheme, opts \\ []) do
    state = %{
      properties: %{}, # uid -> property
      topics:     %{}, # topic -> uid
      contract:   nil,
    }

    IO.inspect(walk(contract_scheme))
    {:ok, walk(contract_scheme)}
  end

  @spec mqtt(mqtt_spec) :: scheme
  def mqtt(foo) do
    {:mqtt, foo}
  end

  defp make_property(spec = %{topic: topic, setter: setter, status: status, getter: getter, type: type}) do
    %{
      contract: %{prop: spec},
      topics: %{topic => 42},
      properties: %{topic => 42},
    }
  end

  defp walk({:mqtt, spec}) do
    {fields, subcontract} = split_map(spec, [:topic, :setter, :status, :getter, :type])
    (state = %{contract: property_contract}) = make_property(spec)
    %{ state | contract: Map.merge(subcontract, property_contract) }
  end

  defp walk(map) when is_map(map) do
    items = Enum.map(map, fn({k, v}) -> {k, walk(v)} end)
    properties = items
      |> Enum.map(fn({_, %{properties: p}}) -> p end)
      |> Enum.reduce(%{}, &Map.merge/2)
    topics = items
      |> Enum.map(fn({_, %{topics: t}}) -> t end)
      |> Enum.reduce(%{}, &Map.merge/2)
    contract = items
      |> Enum.map(fn({k, %{contract: c}}) -> {k, c} end)
      |> Map.new

    %{
      properties: properties,
      topics: topics,
      contract: contract,
    }
  end

  defp walk(list) when is_list(list) do
    items = Enum.map(list, &walk/1)
    properties = items
      |> Enum.map(fn(%{properties: p}) -> p end)
      |> Enum.reduce(%{}, &Map.merge/2)
    topics = items
      |> Enum.map(fn(%{topics: t}) -> t end)
      |> Enum.reduce(%{}, &Map.merge/2)
    contract = items
      |> Enum.map(fn(%{contract: c}) -> c end)

    %{
      properties: properties,
      topics: topics,
      contract: contract,
    }
  end

  defp walk(thing) do
    %{
      properties: %{},
      topics: %{},
      contract: thing
    }
  end

  defp split_map(map, keys) when is_map(map) do
    left  = keys |> Enum.map(fn(k) -> {k, Map.get(map, k)} end) |> Map.new
    right = map  |> Enum.filter(fn({k, _}) -> not Map.has_key?(left, k) end) |> Map.new
    {left, right}
  end
end
