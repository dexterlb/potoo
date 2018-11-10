defmodule Potoo.ContractTest do
  use ExUnit.Case
  doctest Potoo.Contract

  import Potoo.Contract
  alias Potoo.Contract.Delegate
  alias Potoo.Contract.Function

  test "does nothing on non-function base types" do
    assert populate_pids(42, :my_pid)      == 42
    assert populate_pids(42.5, :my_pid)    == 42.5
    assert populate_pids(nil, :my_pid)     == nil
    assert populate_pids("foo", :my_pid)   == "foo"
    assert populate_pids(true, :my_pid)    == true
    assert populate_pids(%Delegate{destination: :other_pid}, :my_pid) == %Delegate{destination: :other_pid}
  end

  test "does nothing on function with pid" do
    assert populate_pids(
      %Function{name: :foo, pid: :other_pid, argument: :integer, retval: :integer},
      :my_pid
    ) ==
      %Function{name: :foo, pid: :other_pid, argument: :integer, retval: :integer}
  end

  test "sets pid function without pid" do
    assert populate_pids(
      %Function{name: :foo, pid: nil, argument: :integer, retval: :integer},
      :my_pid
    ) ==
      %Function{name: :foo, pid: :my_pid, argument: :integer, retval: :integer}
  end

  test "works on nested structure" do
    a = %{
      foo: "some string",
      bar: %Function{name: :foo, pid: nil, argument: :integer, retval: :integer},
      baz: [
        %Function{name: :bar, pid: nil, argument: :string, retval: :string},
        %Function{name: :baz, pid: :a_pid, argument: :string, retval: :string},
      ]
    }

    b = %{
      foo: "some string",
      bar: %Function{name: :foo, pid: :my_pid, argument: :integer, retval: :integer},
      baz: [
        %Function{name: :bar, pid: :my_pid, argument: :string, retval: :string},
        %Function{name: :baz, pid: :a_pid, argument: :string, retval: :string},
      ]
    }

    assert populate_pids(a, :my_pid) == b
  end
end