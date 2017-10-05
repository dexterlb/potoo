defmodule UiWeb.ApiController do
  use UiWeb, :controller

  def call_function(conn, %{"path" => path}) do
    render conn, "call_function.json", path: path
  end
end
