defmodule Ui.Api do

  alias Mesh.ServerUtils.PidCache
  alias Mesh.ServerUtils.Json

  def call(%{"path" => path, "argument" => argument}) do
    PidCache
      |> PidCache.get({:delegates, 0})
      |> Mesh.direct_call(String.split(path, "/"), argument, true)
      |> check_fail
  end

  def get_contract(empty) when empty == %{} do
    get_contract(%{"pid" => 0})
  end

  def get_contract(%{"pid" => pid_id}) when is_integer(pid_id) do
    PidCache
      |> PidCache.get({:delegates, pid_id})
      |> Mesh.get_contract
      |> Json.jsonify_contract(PidCache)
  end

  defp check_fail({:fail, err}) do
    %{"error" => err}
  end
  defp check_fail({:ok, x}), do: x
  defp check_fail(x), do: x
end