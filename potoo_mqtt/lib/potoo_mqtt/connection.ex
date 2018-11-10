defmodule PotooMqtt.Connection do
  use Tortoise.Handler

  require Logger

  def init(arg) do
    {:ok, Map.new(arg)}
  end

  def connection(:down, _) do
    raise "MQTT connection is down :("
  end

  def connection(:up, state = %{topics: topics}) do
    actions = Enum.map(topics, fn(topic) -> {:subscribe, topic, qos: 2} end)
    Logger.debug(fn -> "performing MQTT actions: #{inspect(actions)}" end)
    {:ok, state, actions}
  end

  def handle_message(topic, payload, state = %{target: target}) do
    Logger.debug(fn -> "received MQTT message: #{inspect({topic, payload})}" end)
    send(target, {:mqtt_message, topic, payload})
    {:ok, state}
  end

  def terminate(_, _), do: :ok
end
