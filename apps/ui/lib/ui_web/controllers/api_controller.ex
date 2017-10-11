defmodule UiWeb.ApiController do
  use UiWeb, :controller

  def deep_call(conn, %{"path" => path, "argument" => argument}) do
    root = Ui.PidCache.get(Ui.PidCache, 0)

    result = Mesh.direct_call(root, String.split(path, "/"), argument, true)

    render conn, "generic.json", data: check_fail(result)
  end

  def get_contract(conn, empty) when empty == %{} do
    get_contract(conn, %{"pid" => 0})
  end

  def get_contract(conn, %{"pid" => pid_id}) when is_integer(pid_id) do
    pid = Ui.PidCache.get(Ui.PidCache, pid_id)

    contract = Mesh.get_contract(pid)

    render conn, "generic.json", data: Ui.PidCache.jsonify_contract(contract, Ui.PidCache)
  end

  defp check_fail({:fail, err}) do
    %{"error" => err}
  end
  defp check_fail({:ok, x}), do: x
  defp check_fail(x), do: x
end
