defmodule UiWeb.ApiController do
  use UiWeb, :controller

  def deep_call(conn, %{"path" => path, "argument" => argument}) do
    root = Ui.PidCache.get(Ui.PidCache, 0)

    result = Mesh.fuzzy_deep_call(root, String.split(path, "/"), argument)

    render conn, "generic.json", data: result
  end
end
