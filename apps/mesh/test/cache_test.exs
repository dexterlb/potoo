defmodule CacheTest do
  use ExUnit.Case
  doctest Mesh.Cache

  alias Mesh.Cache
  alias Mesh.Channel
  alias Mesh.Contract.Delegate

  defmodule CacheTest.FooService do
    use GenServer

    def init(children) do
      {:ok, chan} = Mesh.Channel.start_link()

      {:ok, %{children: children, contract_chan: chan}}
    end

    def handle_call(:contract, _from, state = %{children: children}) do
      {:reply, contract(children), state}
    end

    def handle_call(:subscribe_contract, _from, state = %{contract_chan: chan}) do
      {:reply, chan, state}
    end

    def handle_call({"methods.add_child", child = %Mesh.Contract.Delegate{}}, _, state) do
      %{children: children, contract_chan: chan} = state

      new_state = %{ state | children: [child | children] }

      Mesh.Channel.send(chan, new_state.children)

      {:reply, nil, new_state}
    end

    def handle_call({"methods.hello", %{"item" => item}}, _, state) do
      {:reply, "Hello, #{item}!", state}
    end

    defp contract(children) do
      %{
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
          },
          "add_child" => %Mesh.Contract.Function{
            name: "methods.add_child",
            argument: :delegate,
            retval: nil,
            data: %{
              "description" => "Adds a child service"
            }
          }
        },
        "children" => children
      }
    end
  end

  test "can get contract" do
    {:ok, service}  = GenServer.start_link(CacheTest.FooService, [])
    {:ok, cache}    = Cache.start_link()

    assert Cache.get_contract(cache, service) == Mesh.get_contract(service)
  end

  test "can subscribe to contract" do
    {:ok, service}  = GenServer.start_link(CacheTest.FooService, [])
    {:ok, child}    = GenServer.start_link(CacheTest.FooService, [])
    {:ok, cache}    = Cache.start_link()

    chan_a = Cache.subscribe_contract(cache, service)
    chan_b =  Mesh.subscribe_contract(service)

    :ok = Channel.subscribe(chan_a, self(), :cache)
    :ok = Channel.subscribe(chan_b, self(), :mesh)

    :ok = Mesh.deep_call(service, ["methods", "add_child"], %Delegate{
      destination: child
    })

    cache_contract = receive do
      {:cache, data} -> data
    end

    mesh_contract = receive do
      {:mesh, data} -> data
    end

    assert cache_contract == mesh_contract
  end

  test "can call function which is available on the root" do
    {:ok, service}  = GenServer.start_link(CacheTest.FooService, [])
    {:ok, cache}    = Cache.start_link()

    assert(
      Cache.call(cache, service, ["methods", "hello"], %{"item" => "foo"})
      ==
      Mesh.deep_call(service, ["methods", "hello"], %{"item" => "foo"})
    )
  end

  test "can call function on a child" do
    {:ok, service}  = GenServer.start_link(CacheTest.FooService, [])
    {:ok, child}    = GenServer.start_link(CacheTest.FooService, [])
    {:ok, cache}    = Cache.start_link()

    :ok = Mesh.deep_call(service, ["methods", "add_child"], %Delegate{
      destination: child
    })

    assert(
      Cache.call(cache, service, ["children", 0, "methods", "hello"], %{"item" => "foo"})
      ==
      Mesh.deep_call(service, ["children", 0, "methods", "hello"], %{"item" => "foo"})
    )
  end
end
