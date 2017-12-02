defmodule Ui.TcpServer.Handler do
  alias Ui.Api

  def init(_opts) do
    {:ok, nil}
  end

  def socket_handle({:text, text}, state) do
    line = text 
      |> String.replace("\r", "")
      |> String.replace("\n", "")
    
    case line_handle(line, state) do
      {:reply, text, state} -> {:reply, [text, "\n"], state}
      other -> other
    end
  end

  def socket_info({{:subscription, token}, message}, state) do
    message 
      |> Api.jsonify
      |> reply_json(state, [token])
  end

  defp line_handle("ping", state) do
    {:reply, "pong", state}
  end

  defp line_handle(json_data, state) do
    json_data |> Poison.decode! |> json_handle(state)
  end


  defp json_handle("ping", state) do
    reply_json("pong", state)
  end
  
  defp json_handle(["get_contract", arg | token], state) do
    Api.get_contract(arg) |> reply_json(state, token)
  end

  defp json_handle(["subscribe_contract", arg | token], state) do
    Api.subscribe_contract(arg) |> reply_json(state, token)
  end

  defp json_handle(["get_and_subscribe_contract", arg | token], state) do
    Api.get_and_subscribe_contract(arg) |> reply_json(state, token)
  end

  defp json_handle(["call", arg | token], state) do
    Api.call(arg) |> reply_json(state, token)
  end

  defp json_handle(["unsafe_call", arg | token], state) do
    Api.unsafe_call(arg) |> reply_json(state, token)
  end

  defp json_handle(["subscribe", arg | token], state) do
    Api.subscribe(arg) |> reply_json(state, token)
  end

  defp json_handle(["unsubscribe", arg | token], state) do
    Api.unsubscribe(arg) |> reply_json(state, token)
  end

  defp json_handle(data, state) do
    reply_json(%{"data" => data}, state)
  end


  defp reply_json(data, state, token \\ [])
  defp reply_json(data, state, []) do
    {:reply, encode_json(data), state}
  end

  defp reply_json(data, state, token) do
    {:reply, encode_json([data | token]), state}
  end

  defp encode_json(data) do
    Poison.encode!(data, pretty: Application.get_env(:ui, :json_pretty, false))
  end
end