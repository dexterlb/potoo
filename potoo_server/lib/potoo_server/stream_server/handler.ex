defmodule PotooServer.StreamServer.Handler do
  alias PotooServer.Api
  alias PotooServer.StreamServer.ReverseEndpoint
  require OK
  alias Potoo.ServerUtils.Json
  alias Potoo.ServerUtils.PidCache
  require Logger

  def init(_opts \\ []) do
    send(self(), {__MODULE__, :begin})

    OK.for do
      endpoint <- ReverseEndpoint.start_link(self())
    after
      %{
        endpoint: endpoint,
        active_calls: %{},
      }
    end
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

  def socket_info({__MODULE__, :begin}, state) do
    reply_json("hello", state)
  end

  def socket_info({{:subscription, token}, message}, state) do
    message
      |> reply_json(state, [token])
  end

  def socket_info({:incoming_call, from, {function, argument}}, state = %{active_calls: active_calls}) do
    call_ref = random_string(64)

    new_active_calls = Map.put(active_calls, call_ref, from)
    Process.send_after(self(), {:drop_call, call_ref}, 10000)

    ["call", %{"from" => call_ref, "function" => function, "argument" => argument}]
      |> reply_json(%{state | active_calls: new_active_calls})
  end

  def socket_info({:drop_call, ref}, state = %{active_calls: active_calls}) do
    {:noreply, %{state | active_calls: Map.delete(active_calls, ref)}}
  end

  defp line_handle("", state) do
    {:noreply, state}
  end

  defp line_handle("ping", state) do
    {:reply, "pong", state}
  end

  defp line_handle(json_data, state) do
    case json_data |> Poison.decode! |> unjsonify do
      {:ok, data}   -> json_handle(data, state)
      {:error, err} -> jsonify(%{
        "error" => "unable to parse input: #{inspect(err)}"
      })
    end
  end

  defp json_handle(["return", %{"to" => ref, "value" => retval} | token], state = %{active_calls: active_calls}) do
    case Map.get(active_calls, ref) do
      nil -> %{"error" => "call has expired", "ref" => ref}
      to  -> case GenServer.reply(to, retval) do
        :ok -> "ok"
        err -> %{"error" => "cannot reply", "data" => err}
      end

    end |> reply_json(state, token)
  end

  defp json_handle(["set_contract", contract | token], state = %{endpoint: endpoint}) do
    :ok = GenServer.call(endpoint, {:set_contract, contract})
    reply_json("ok", state, token)
  end

  defp json_handle(["my_pid" | token], state = %{endpoint: endpoint}) do
    Api.my_pid(endpoint) |> reply_json(state, token)
  end

  defp json_handle(["make_channel" | token], state) do
    Api.make_channel |> reply_json(state, token)
  end

  defp json_handle(["send_on", %{"channel" => chan, "message" => msg} | token], state) do
    Api.send_on(chan, msg) |> reply_json(state, token)
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
    Poison.encode!(jsonify(data), pretty: Application.get_env(:potoo_server, :json_pretty, false))
  end

  @random_string_chars "0123456789abcdefghijklmnopqrstuvwxyz" |> String.split("")

  defp random_string(length) do
    Enum.reduce((1..length), [], fn (_i, acc) ->
      [Enum.random(@random_string_chars) | acc]
    end) |> Enum.join("")
  end

  def jsonify(data) do
    Json.jsonify(data, PidCache)
  end

  def unjsonify(json) do
    Json.unjsonify(json, PidCache)
  end
end
