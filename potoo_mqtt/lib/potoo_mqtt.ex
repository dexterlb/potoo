defmodule PotooMqtt do
  use GenServer

  require OK
  require Logger

  alias Potoo.Contract
  alias Potoo.Contract.Function
  alias Potoo.Contract.Delegate
  alias Potoo.Channel

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
    :instant         => true | false,
    :type            => Type.t,
  }


  def start_link(opts, genserver_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, genserver_opts)
  end

  def init(opts) do
    opts_map = Map.new(opts)

    registry = Map.get(opts_map, :registry)
    if registry != nil do
      :ok = Potoo.deep_call(registry, ["register"], %{
        "name" => Map.get(opts_map, :reg_name, random_string(10)),
        "delegate" => %Delegate{destination: self()},
      })
    end

    contract_scheme = Map.fetch!(opts_map, :scheme)
    server          = Map.fetch!(opts_map, :potoo_server)

    OK.for do
      contract_channel <- Potoo.Channel.start_link()
      state = Map.merge(walk(contract_scheme), %{
        contract_channel: contract_channel,
      })

      connection_data <- setup_connection(state, server)
    after
      {:ok, Map.merge(state, connection_data)}
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
    case Map.fetch(properties, id) do
      {:ok, prop} -> handle_func({id, prop, func, arg}, from, state)
      _           -> {:error, {:no_such_id, id}}
    end
  end

  def handle_info({:mqtt_message, topic, payload}, state = %{topics: topics}) do
    case Map.fetch(topics, Enum.join(topic, "/")) do
      {:ok, prop_id} ->
        handle_status(prop_id, payload, state)
      _              ->
        Logger.warn(fn -> "received unknown MQTT message: #{inspect(topic)}" end)
        {:noreply, state}
    end
  end

  defp handle_func({_, %{value: value}, "get", _}, _, state) do
    {:reply, value, state}
  end

  defp handle_func({_, %{channel: channel}, "subscribe", _}, _, state) do
    {:reply, channel, state}
  end

  defp handle_func({prop_id, %{setter: {topic, show}, instant: instant, channel: chan}, "set", value}, _, state = %{connection_id: conn_id}) do
    Tortoise.publish(conn_id, topic, show.(value))
    if instant do
      Channel.send_lazy(chan, fn -> value end)
      {:reply, nil, put_in(state[:properties][prop_id][:value], value)}
    else
      {:reply, nil, state}
    end
  end

  defp handle_status(prop_id, payload, state = %{properties: properties}) do
    %{status: {topic, parse}, channel: chan} = Map.fetch!(properties, prop_id)

    try do
      value = parse.(payload)
      Logger.debug("send to #{inspect(chan)}: #{inspect(value)}")
      Channel.send_lazy(chan, fn -> value end)
      {:noreply, put_in(state[:properties][prop_id][:value], value)}
    rescue e ->
      Logger.warn(fn -> "#{topic}: unable to parse #{inspect(payload)}: #{inspect(e)}" end)
      {:noreply, state}
    end
  end

  defp setup_connection(%{topics: topics}, server) do
    OK.for do
      conn_id = random_string(16)
      conn <- Tortoise.Connection.start_link(
        client_id: conn_id,
        server: server,
        handler: {PotooMqtt.Connection, [topics: Map.keys(topics), target: self()]}
      )
    after
      %{
        connection: conn,
        connection_id: conn_id,
      }
    end
  end

  defp make_property(%{topic: topic, setter: setter, status: status, instant: instant, default: default, getter: getter, type: type}) do
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
        setter: setter_func("#{topic}/#{setter}", type),
        getter: "#{topic}/#{getter}",
        status: status_func("#{topic}/#{status}", type),
        channel: Potoo.Channel.start_link!(),
        instant: instant,
      }},
    }
  end

  defp walk({:mqtt, spec}) do
    {fields, subcontract} = split_map(spec, [:topic, :setter, :status, :getter, :default, :instant, :type])
    (state = %{contract: property_contract}) = make_property(fields)
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

  defp setter_func({topic, func}, _type), do: {topic, func}
  defp setter_func(topic, _type) do
    {topic, fn(x) -> inspect(x) end}
  end

  defp status_func({topic, func}, _type), do: {topic, func}
  defp status_func(topic, {:type, t, _}), do: status_func(topic, t)
  defp status_func(topic, :bool), do: {topic, &parse_bool/1}
  defp status_func(topic, :float), do: {topic, &parse_float/1}

  defp parse_bool("1"), do: true
  defp parse_bool("true"), do: true
  defp parse_bool(_), do: false

  defp parse_float(s) do
    {f, _} = Float.parse(s)
    f
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
