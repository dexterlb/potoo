defmodule UiWeb.ApiView do
  use UiWeb, :view

  def render("foo.json", _) do
    %{"foo" => "bar"}
  end
end
