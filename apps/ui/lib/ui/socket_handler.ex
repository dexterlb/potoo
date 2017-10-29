defmodule Ui.SocketHandler do
  alias Ui.Api

  @behaviour :cowboy_websocket_handler

  def init(_, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  @timeout 60000 # terminate if no activity for one minute

  #Called on websocket connection initialization.
  def websocket_init(_type, req, _opts) do
    state = %{}
    {:ok, req, state, @timeout}
  end

  # Handle 'ping' messages from the browser - reply
  def websocket_handle({:text, "ping"}, req, state) do
    {:reply, {:text, "pong"}, req, state}
  end
  
  # Handle other messages from the browser - don't reply
  def websocket_handle({:text, json_data}, req, state) do
    json_data |> Poison.decode! |> json_handle(req, state)
  end

  # Format and forward elixir messages to client
  def websocket_info(message, req, state) do
    {:reply, {:text, message}, req, state}
  end

  # No matter why we terminate, remove all of this pids subscriptions
  def websocket_terminate(_reason, _req, _state) do
    :ok
  end

  defp json_handle(["get_contract", arg], req, state) do
    Api.get_contract(arg) |> reply_json(req, state)
  end

  defp json_handle(["call", arg], req, state) do
    Api.call(arg) |> reply_json(req, state)
  end

  defp json_handle(["unsafe_call", arg], req, state) do
    Api.unsafe_call(arg) |> reply_json(req, state)
  end

  defp json_handle(data, req, state) do
    reply_json(%{"data" => data}, req, state)
  end

  defp reply_json(data, req, state) do
    {:reply, {:text, encode_json(data)}, req, state}
  end

  defp encode_json(data) do
    Poison.encode!(data, pretty: Application.get_env(:ui, :json_pretty, false))
  end
end