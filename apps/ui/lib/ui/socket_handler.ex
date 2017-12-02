defmodule Ui.SocketHandler do
  alias Ui.Api
  require Logger

  @behaviour :cowboy_websocket_handler

  def init(_, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  @timeout 10000 # terminate if no activity for one minute

  #Called on websocket connection initialization.
  def websocket_init(_type, req, _opts) do
    state = %{}

    Logger.debug(fn -> ["new ws client: ", inspect(req)] end)

    {:ok, req, state, @timeout}
  end

  # Handle 'ping' messages from the browser - reply
  def websocket_handle({:text, "ping"}, req, state) do
    {:reply, {:text, "pong"}, req, state}
  end
  
  # Handle other messages from the browser - don't reply
  def websocket_handle({:text, json_data}, req, state) do
    data = json_data |> Poison.decode!

    Logger.debug(fn -> ["ws -> ", inspect(data)] end)

    data |> json_handle(req, state)
  end

  def websocket_info({{:subscription, token}, message}, req, state) do
    message 
      |> Api.jsonify
      |> reply_json(req, state, [token])
  end
  
  # Format and forward elixir messages to client
  def websocket_info(message, req, state) do
    {:reply, {:text, message}, req, state}
  end

  # No matter why we terminate, remove all of this pids subscriptions
  def websocket_terminate(_reason, req, _state) do
    Logger.debug(fn -> ["ws conn died: ", inspect(req)] end)
    :ok
  end

  defp json_handle("ping", req, state) do
    reply_json("pong", req, state)
  end

  defp json_handle(["get_contract", arg | token], req, state) do
    Api.get_contract(arg) |> reply_json(req, state, token)
  end

  defp json_handle(["subscribe_contract", arg | token], req, state) do
    Api.subscribe_contract(arg) |> reply_json(req, state, token)
  end

  defp json_handle(["get_and_subscribe_contract", arg | token], req, state) do
    Api.get_and_subscribe_contract(arg) |> reply_json(req, state, token)
  end

  defp json_handle(["call", arg | token], req, state) do
    Api.call(arg) |> reply_json(req, state, token)
  end

  defp json_handle(["unsafe_call", arg | token], req, state) do
    Api.unsafe_call(arg) |> reply_json(req, state, token)
  end

  defp json_handle(["subscribe", arg | token], req, state) do
    Api.subscribe(arg) |> reply_json(req, state, token)
  end

  defp json_handle(["unsubscribe", arg | token], req, state) do
    Api.unsubscribe(arg) |> reply_json(req, state, token)
  end

  defp json_handle(data, req, state) do
    reply_json(%{"data" => data}, req, state)
  end

  defp reply_json(data, req, state, token \\ [])
  defp reply_json(data, req, state, []) do
    Logger.debug(fn -> ["ws <- ", inspect(data)] end)
    {:reply, {:text, encode_json(data)}, req, state}
  end

  defp reply_json(data, req, state, token) do
    Logger.debug(fn -> ["ws <- ", inspect([data | token])] end)
    {:reply, {:text, encode_json([data | token])}, req, state}
  end

  defp encode_json(data) do
    Poison.encode!(data, pretty: Application.get_env(:ui, :json_pretty, false))
  end
end