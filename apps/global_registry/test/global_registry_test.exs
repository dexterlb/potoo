defmodule GlobalRegistryTest do
  use ExUnit.Case
  doctest GlobalRegistry

  test "greets the world" do
    assert GlobalRegistry.hello() == :world
  end
end
