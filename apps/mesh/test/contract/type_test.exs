defmodule TypeTest do
  use ExUnit.Case
  doctest Contract.Type

  import Contract.Type

  test "types I think are valid are valid" do
    assert is_valid(nil) == true
    assert is_valid(:bool) == true
    assert is_valid(:atom) == true
    assert is_valid(:float) == true
    assert is_valid(:integer) == true
    assert is_valid(:string) == true
    assert is_valid({:union, :string, nil}) == true
    assert is_valid({:union, {:union, :float, :string}, :integer}) == true
    assert is_valid({:list, :string}) == true
    assert is_valid({:map, :string, :integer}) == true
    assert is_valid({:struct, %{"foo" => :integer, "bar" => :float}})
    assert is_valid({:type, :integer, %{"foo" => "bar"}}) == true
    assert is_valid({:struct, %{"foo" => {:type, :integer, %{"description" => "the Foo field"}}}}) == true
  end

  test "types I think are not valid are not valid" do
    assert is_valid(42) == false
    assert is_valid(:foo) == false
    assert is_valid({:list, {:union, :string, :foo}}) == false
  end

  test "types of some samples are correct" do
    assert is_of(nil, nil) == true

    assert is_of(:bool, true) == true
    assert is_of(:bool, false) == true
    assert is_of(:bool, 42) == false

    assert is_of(:integer, 42) == true
    assert is_of(:integer, 42.5) == false

    assert is_of(:float, 42.5) == true
    assert is_of(:float, 42) == false
    assert is_of(:float, nil) == false

    assert is_of(:string, "foo") == true
    assert is_of(:string, 42) == false

    assert is_of({:union, :integer, :string}, "42") == true
    assert is_of({:union, :integer, :string}, 42) == true
    assert is_of({:union, :integer, :string}, 42.5) == false

    assert is_of({:list, :integer}, [1, 2, 3]) == true
    assert is_of({:list, :integer}, [1, "2", 3]) == false
    assert is_of({:list, {:union, :integer, :string}}, [1, "2", 3]) == true

    assert is_of({:map, :string, :integer}, %{"foo" => 5, "bar" => 42}) == true
    assert is_of({:map, :string, :integer}, %{:foo => 5, "bar" => 42}) == false
    assert is_of({:map, :string, :integer}, %{"foo" => 5.5, "bar" => 42}) == false

    assert is_of(
      {:struct, %{"foo" => :integer, "bar" => :float}},
      %{"foo" => 42, "bar" => 42.5}
    ) == true

    assert is_of(
      {:struct, %{"foo" => :integer, "bar" => :float}},
      %{"foo" => 42, "bar" => :not_float}
    ) == false

    assert is_of({:type, :integer, %{"description" => "answer"}}, 42) == true
    assert is_of({:type, :integer, %{"description" => "answer"}}, "42") == false

    assert is_of(
      {:struct, %{"foo" => 
        {:type, :integer, %{"description" => "the Foo field"}}, "bar" => :float}
      },
      %{"foo" => 42, "bar" => 42.5}
    ) == true

    assert is_of(
      {:struct, %{"foo" => 
        {:type, :integer, %{"description" => "the Foo field"}}, "bar" => :float}
      },
      %{"foo" => :not_int, "bar" => 42.5}
    ) == false
  end
end
