defmodule UiWeb.ApiController do
  use UiWeb, :controller

  alias Mesh.ServerUtils.PidCache
  alias Mesh.ServerUtils.Json

  def deep_call(conn, %{"path" => path, "argument" => argument}) do
    root = PidCache.get(PidCache, {:delegates, 0})

    result = Mesh.direct_call(root, String.split(path, "/"), argument, true)

    render conn, "generic.json", data: check_fail(result)
  end

  def get_contract(conn, empty) when empty == %{} do
    get_contract(conn, %{"pid" => 0})
  end

  def get_contract(conn, %{"pid" => pid_id}) when is_integer(pid_id) do
    pid = PidCache.get(PidCache, {:delegates, pid_id})

    contract = Mesh.get_contract(pid)

    render conn, "generic.json", data: Json.jsonify_contract(contract, PidCache)
  end

  defp check_fail({:fail, err}) do
    %{"error" => err}
  end
  defp check_fail({:ok, x}), do: x
  defp check_fail(x), do: x
end
