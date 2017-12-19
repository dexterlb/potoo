defmodule Ui.Api do

  alias Mesh.ServerUtils.PidCache
  alias Mesh.ServerUtils.Json

  require Logger
  require OK

  def call(%{"pid" => pid, "path" => path, "argument" => argument}) when is_integer(pid) do
    PidCache
      |> PidCache.get({:delegate, pid})
      |> Mesh.direct_call(String.split(path, "/"), argument, true)
      |> check_fail
      |> jsonify
  end

  def call(%{"path" => _, "argument" => _} = handle) do
    call(Map.put(handle, "pid", 0))
  end

  def subscribe(%{"channel" => chan_id, "token" => token}) when is_integer(chan_id) do
    {Mesh.Channel, PidCache.get(PidCache, {:channel, chan_id})}
      |> Mesh.Channel.subscribe(self(), {:subscription, token})
  end

  def unsubscribe(%{"channel" => chan_id, "token" => token}) when is_integer(chan_id) do
    {Mesh.Channel, PidCache.get(PidCache, {:channel, chan_id})}
      |> Mesh.Channel.unsubscribe(self(), {:subscription, token})
  end

  def unsafe_call(%{"pid" => pid, "function_name" => name, "argument" => argument}) when is_integer(pid) do
    PidCache
      |> PidCache.get({:delegate, pid})
      |> Mesh.unsafe_call(name, argument)
      |> jsonify
  end

  def get_contract(empty) when empty == %{} do
    get_contract(%{"pid" => 0})
  end

  def get_contract(%{"pid" => pid_id}) when is_integer(pid_id) do
    case PidCache.get(PidCache, {:delegate, pid_id}) do
      nil -> %{"error" => "no such pid: #{pid_id}"}
      pid -> pid
        |> Mesh.get_contract
        |> jsonify
    end
  end

  def subscribe_contract(empty) when empty == %{} do
    subscribe_contract(%{"pid" => 0})
  end

  def subscribe_contract(%{"pid" => pid_id}) when is_integer(pid_id) do
    case PidCache.get(PidCache, {:delegate, pid_id}) do
      nil -> %{"error" => "no such pid: #{pid_id}"}
      pid -> pid
        |> Mesh.subscribe_contract
        |> jsonify
    end
  end

  def get_and_subscribe_contract(%{"pid" => pid_id, "token" => token}) do
    case PidCache.get(PidCache, {:delegate, pid_id}) do
      nil -> %{"error" => "no such pid: #{pid_id}"}
      pid ->
        contract = Mesh.get_contract(pid)

        case Mesh.subscribe_contract(pid) do
          {Mesh.Channel, _} = channel -> 
            :ok = Mesh.Channel.subscribe(channel, self(), {:subscription, token})

            contract

          err -> err
        end |> jsonify
    end
  end

  def my_pid(endpoint) do
    PidCache.get(PidCache, {:delegate, endpoint})
  end

  def make_channel() do
    {:ok, chan} = Mesh.Channel.start_link()
    chan |> jsonify
  end

  def send_on(channel, message) do
    {:ok, status} = OK.for do
      chan <- unjsonify(channel)
      msg  <- unjsonify(message)  # ugly code! all rubyists cringe!
    after
      Mesh.Channel.send(chan, msg) |> jsonify
    end

    status
  end


  def jsonify(data) do
    Json.jsonify(data, PidCache)
  end

  def unjsonify(json) do
    Json.unjsonify(json, PidCache)
  end

  defp check_fail({:fail, err}) do
    %{"error" => err}
  end
  defp check_fail({:ok, x}), do: x
  defp check_fail(x), do: x
end