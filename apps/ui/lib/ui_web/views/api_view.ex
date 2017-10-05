defmodule UiWeb.ApiView do
  use UiWeb, :view

  def render("call_function.json", %{path: path}) do
    %{"foo" => path}
  end
end
