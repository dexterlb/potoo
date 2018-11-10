defmodule UiTest do
  use ExUnit.Case
  doctest PotooServer

  test "greets the world" do
    assert PotooServer.hello() == :world
  end
end
