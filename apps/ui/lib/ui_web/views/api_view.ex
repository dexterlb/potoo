defmodule UiWeb.ApiView do
  use UiWeb, :view

  def render("generic.json", %{data: data}) do
    data
  end
end
