defmodule Ui.Api do

  alias Mesh.ServerUtils.PidCache
  alias Mesh.ServerUtils.Json

  def call(%{"path" => path, "argument" => argument}) do
    PidCache
      |> PidCache.get({:delegate, 0})
      |> Mesh.direct_call(String.split(path, "/"), argument, true)
      |> check_fail
  end

  def call(%{"pid" => pid, "function" => function, "argument" => argument}) when is_integer(pid) do
    PidCache
      |> PidCache.get({:delegate, pid})
      |> Mesh.call(function, argument, true)
      |> check_fail
  end

  def get_contract(empty) when empty == %{} do
    get_contract(%{"pid" => 0})
  end

  def get_contract(%{"pid" => pid_id}) when is_integer(pid_id) do
    case PidCache.get(PidCache, {:delegate, pid_id}) do
      nil -> %{"error" => "no such pid: #{pid_id}"}
      pid -> pid
        |> Mesh.get_contract
        |> Json.jsonify_contract(PidCache)
    end
  end

  defp check_fail({:fail, err}) do
    %{"error" => err}
  end
  defp check_fail({:ok, x}), do: x
  defp check_fail(x), do: x
end