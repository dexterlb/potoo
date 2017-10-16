defmodule TypeTest do
  use ExUnit.Case
  doctest Contract.Type

  import Contract.Type
  require Mesh.Channel

  test "types I think are valid are valid" do
    assert is_valid(nil) == true
    assert is_valid(:bool) == true
    assert is_valid(:atom) == true
    assert is_valid(:float) == true
    assert is_valid(:integer) == true
    assert is_valid(:string) == true
    assert is_valid(:delegate) == true
    assert is_valid({:literal, :error}) == true
    assert is_valid({:channel, :string}) == true
    assert is_valid({:union, :string, nil}) == true
    assert is_valid({:union, {:union, :float, :string}, :integer}) == true
    assert is_valid({:list, :string}) == true
    assert is_valid({:map, :string, :integer}) == true
    assert is_valid({:struct, %{"foo" => :integer, "bar" => :float}})
    assert is_valid({:struct, [:integer, :string]})
    assert is_valid({:type, :integer, %{"foo" => "bar"}}) == true
    assert is_valid({:struct, %{"foo" => {:type, :integer, %{"description" => "the Foo field"}}}}) == true
  end

  test "types I think are not valid are not valid" do
    assert is_valid(42) == false
    assert is_valid(:foo) == false
    assert is_valid({:channel, :foo}) == false
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

    assert is_of(:delegate, %Mesh.Contract.Delegate{}) == true
    assert is_of(:delegate, %{}) == false

    {:ok, chan} = Mesh.Channel.start_link()
    assert is_of({:channel, :string}, chan) == true
    assert is_of({:channel, :string}, self()) == false

    assert is_of({:literal, :error}, :error) == true
    assert is_of({:literal, :error}, :foo) == false

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

    assert is_of({:struct, [:integer, :float]}, [42, 42.5]) == true
    assert is_of({:struct, [:integer, :float]}, [42.5, 42]) == false

    assert is_of({:struct, {:integer, :float}}, {42, 42.5}) == true
    assert is_of({:struct, {:integer, :float}}, {42.5, 42}) == false

    assert is_of({:struct, {:integer, :float}}, [42, 42.5]) == false
  end

  test "some casts work" do
    assert cast("42", :integer) == {:ok, 42}
    assert cast(42, :float) == {:ok, 42}
    assert cast("42.5", :float) == {:ok, 42.5}
    
    assert cast(42, :string) == {:ok, "42"}
    assert cast(42.5, :string) == {:ok, "42.5"}

    assert cast("true", :bool) == {:ok, true}
    assert cast("false", :bool) == {:ok, false}

    assert cast(
      %{"foo" => "42", "bar" => "26"},
      {:struct, %{"foo" => :integer, "bar" => :float}}
    ) == {:ok, %{"foo" => 42, "bar" => 26.0}}

    assert cast(
      ["42", "26"],
      {:struct, [:integer, :float]}
    ) == {:ok, [42, 26.0]}

    assert cast(
      {"42", "26"},
      {:struct, [:integer, :float]}
    ) == {:ok, [42, 26.0]}

    assert cast(
      ["42", "26"],
      {:struct, {:integer, :float}}
    ) == {:ok, {42, 26.0}}

    assert cast(
      {"42", "26"},
      {:struct, {:integer, :float}}
    ) == {:ok, {42, 26.0}}

    assert cast(
      {"42", "26"},
      {:type, {:struct, [{:type, :integer, %{"foo" => "bar"}}, :float]}, %{}}
    ) == {:ok, [42, 26.0]}

    assert cast(
      ["42", 26.0],
      {:list, :integer}
    ) == {:ok, [42, 26]}

    assert cast(
      :foo,
      {:literal, :foo}
    ) == {:ok, :foo}

    assert cast(
      %{"foo" => "42", "bar" => "26"},
      {:map, :string, :integer}
    ) == {:ok, %{"foo" => 42, "bar" => 26}}

    assert cast(
      %{42 => "42", 26 => "26"},
      {:map, :string, :integer}
    ) == {:ok, %{"42" => 42, "26" => 26}}

    assert cast(
      %{"foo" => "42", "bar" => "26"},
      {:union,
        {:map, :string, :integer},
        :integer
      }
    ) == {:ok, %{"foo" => 42, "bar" => 26}}
  end
end
