defmodule Ui.TcpServer.Handler do
  alias Ui.Api
  # todo:
  # keep contract in the endpoint, allow setting from tcp
  # allow make_channel

  def init(_opts) do
    {:ok, %{
      endpoint: Api.start_endpoint(),
      active_calls: %{},
    }}
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

  def socket_info({:incoming_call, from, call}, state = %{active_calls: active_calls}) do
    call_ref = :rand.uniform(9223372036854775808)
    
    new_active_calls = Map.put(active_calls, call_ref, from)
    Process.send_after(self(), {:drop_call, call_ref}, 10000)

    ["call", %{"from" => call_ref, "argument" => call}]
      |> Api.jsonify
      |> reply_json(%{state | active_calls: new_active_calls})
  end

  def socket_info({:drop_call, ref}, state = %{active_calls: active_calls}) do
    {:noreply, %{state | active_calls: Map.delete(active_calls, ref)}}
  end

  defp line_handle("", state) do
    {:noreply, state}
  end

  defp line_handle("ping", state = %{endpoint: endpoint}) do
    {:reply, "pong", state}
  end

  defp line_handle(json_data, state) do
    json_data |> Poison.decode! |> json_handle(state)
  end


  defp json_handle(["my_pid" | token], state = %{endpoint: endpoint}) do
    Api.my_pid(endpoint) |> reply_json(state, token)
  end

  defp json_handle(["return", %{"to" => ref, "value" => retval} | token], state = %{active_calls: active_calls}) do
    case Map.get(active_calls, ref) do
      nil -> %{"error" => "call has expired", "ref" => ref}
      to  -> case GenServer.reply(to, retval) do
        :ok -> "ok"
        err -> Api.jsonify(%{"error" => "cannot reply", "data" => err})
      end

    end |> reply_json(state, token)
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
    {:reply, [encode_json(data), "\n"], state}
  end

  defp reply_json(data, state, token) do
    {:reply, [encode_json([data | token]), "\n"], state}
  end

  defp encode_json(data) do
    Poison.encode!(data, pretty: Application.get_env(:ui, :json_pretty, false))
  end
end