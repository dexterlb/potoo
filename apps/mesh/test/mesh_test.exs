defmodule MeshTest do
  use ExUnit.Case
  doctest Mesh

  defmodule MeshTest.FooService do
    use GenServer

    @contract %{
      "description" => "A service which provides a greeting.",
      "methods" => %{
        "hello" => %Mesh.Contract.Function{
          name: "methods.hello",
          argument: {:struct, %{
            "item" => {:type, :string, %{
              "description" => "item to greet"
            }}
          }},
          retval: :string,
          data: %{
            "description" => "Performs a greeting"
          }
        }
      }
    }

    def handle_call(:contract, _from, state) do
      {:reply, @contract, state}
    end

    def handle_call(:subscribe_contract, _from, state) do
      {:reply, @contract, state}
    end

    def handle_call({"methods.hello", %{"item" => item}}, _, state) do
      {:reply, "Hello, #{item}!", state}
    end
  end

  test "can call function from contract" do
    {:ok, pid} = GenServer.start_link(MeshTest.FooService, nil)

    contract = Mesh.get_contract(pid)

    hello = Kernel.get_in(contract, ["methods", "hello"])

    assert hello != nil

    assert Mesh.call(pid, hello, %{"item" => "foo"}) == "Hello, foo!"
  end

  test "can call function by name (unsafe call)" do
    {:ok, pid} = GenServer.start_link(MeshTest.FooService, nil)

    contract = Mesh.get_contract(pid)

    hello = Kernel.get_in(contract, ["methods", "hello"])

    assert hello != nil

    assert Mesh.unsafe_call(pid, hello.name, %{"item" => "foo"}) == "Hello, foo!"
  end

  test "can call function with deep call" do
    {:ok, pid} = GenServer.start_link(MeshTest.FooService, nil)

    assert Mesh.deep_call(pid, ["methods", "hello"], %{"item" => "foo"})
      == "Hello, foo!"
  end
end
