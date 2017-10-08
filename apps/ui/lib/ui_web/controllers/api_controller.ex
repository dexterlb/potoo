defmodule UiWeb.ApiController do
  use UiWeb, :controller

  def deep_call(conn, %{"path" => path, "argument" => argument}) do
    root = Ui.PidCache.get(Ui.PidCache, 0)

    result = Mesh.direct_call(root, String.split(path, "/"), argument, true)

    render conn, "generic.json", data: result
  end
end
