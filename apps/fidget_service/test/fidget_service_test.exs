defmodule FidgetServiceTest do
  use ExUnit.Case
  doctest FidgetService

  test "greets the world" do
    assert FidgetService.hello() == :world
  end
end
