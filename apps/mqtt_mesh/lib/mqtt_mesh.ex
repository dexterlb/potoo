defmodule MqttMesh do
  use GenServer

  require OK

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
    :default         => term,
    :type            => Type.t,
  }


  def start_link(opts, genserver_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, genserver_opts)
  end

  def init(opts) do
    opts_map = Map.new(opts)

    registry = Map.get(opts_map, :registry)
    if registry != nil do
      :ok = Mesh.deep_call(registry, ["register"], %{
        "name" => Map.get(opts_map, :reg_name, random_string(10)),
        "delegate" => %Delegate{destination: self()},
      })
    end

    contract_scheme = Map.fetch!(opts_map, :scheme)

    OK.for do
      contract_channel <- Mesh.Channel.start_link()
    after
      {:ok, Map.merge(walk(contract_scheme), %{
        contract_channel: contract_channel,
      })}
    end
  end

  @spec mqtt(mqtt_spec) :: scheme
  def mqtt(foo) do
    {:mqtt, foo}
  end

  def handle_call(:contract, _from, state = %{contract: contract}) do
    {:reply, contract, state}
  end

  def handle_call(:subscribe_contract, _from, state = %{contract_channel: chan}) do
    {:reply, chan, state}
  end

  def handle_call({name, arg}, from, state = %{properties: properties}) do
    [id, func] = String.split(name, ".")
    case Map.get(properties, id) do
      prop -> handle_func({id, prop, func, arg}, from, state)
      _    -> {:error, {:no_such_id, id}}
    end
  end

  def handle_func({_, %{value: value}, "get", _}, _, state) do
    {:reply, value, state}
  end

  def handle_func({_, %{channel: channel}, "subscribe", _}, _, state) do
    {:reply, channel, state}
  end

  defp make_property(spec = %{topic: topic, setter: setter, status: status, default: default, getter: getter, type: type}) do
    id = random_string(24)
    %{
      contract: %{
        "get" => %Function{
          name: "#{id}.get",
          argument: nil,
          retval: type,
        },
        "set" => %Function{
          name: "#{id}.set",
          argument: type,
          retval: nil,
        },
        "subscribe" => %Function{
          name: "#{id}.subscribe",
          argument: nil,
          retval: {:channel, type},
        },
      },
      topics: %{
        "#{topic}/#{status}" => id,
      },
      properties: %{id => %{
        value: default,
        channel: Mesh.Channel.start_link(),
      }},
    }
  end

  defp walk({:mqtt, spec}) do
    {fields, subcontract} = split_map(spec, [:topic, :setter, :status, :getter, :default, :type])
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

  @random_string_chars "0123456789abcdefghijklmnopqrstuvwxyz" |> String.split("")

  defp random_string(length) do
    Enum.reduce((1..length), [], fn (_i, acc) ->
      [Enum.random(@random_string_chars) | acc]
    end) |> Enum.join("")
  end
end
