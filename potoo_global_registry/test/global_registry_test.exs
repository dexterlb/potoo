defmodule PotooGlobalRegistryTest do
  use ExUnit.Case
  doctest PotooGlobalRegistry

  test "greets the world" do
    assert PotooGlobalRegistry.hello() == :world
  end
end
