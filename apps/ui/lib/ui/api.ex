defmodule Ui.Api do

  alias Mesh.ServerUtils.PidCache
  alias Mesh.ServerUtils.Json

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

  def jsonify(data) do
    Json.jsonify_contract(data, PidCache)
  end

  defp check_fail({:fail, err}) do
    %{"error" => err}
  end
  defp check_fail({:ok, x}), do: x
  defp check_fail(x), do: x
end