defmodule UiWeb.ApiController do
  use UiWeb, :controller

  def foo(conn, _params) do
    render conn, :foo
  end
end
