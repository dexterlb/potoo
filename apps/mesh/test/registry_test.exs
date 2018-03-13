defmodule RegistryTest do
  use ExUnit.Case
  doctest Registry

  defmodule RegistryTest.Hello do
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

    def init(state) do
      {:ok, state}
    end

    def handle_call(:contract, _from, state) do
      {:reply, @contract, state}
    end

    def handle_call(:die, _from, state) do
      {:stop, :normal, state}
    end

    def handle_call(:crash, _from, state) do
      {:reply, "Stare into the abyss: #{1/(fn -> 0 end).()}", state}
    end

    def handle_call({"methods.hello", %{"item" => item}}, _, state) do
      {:reply, "Hello, #{item}!", state}
    end
  end

  test "can register service" do
    {:ok, registry} = Mesh.Registry.start_link(%{})

    {:ok, hello} = GenServer.start_link(RegistryTest.Hello, nil)

    :ok = Mesh.deep_call(registry, ["register"], %{
        "name" => "hello_service",
        "delegate" => %Mesh.Contract.Delegate{destination: hello}
    })

    registry_contract = Mesh.get_contract(registry)

    assert registry_contract != nil

    hello_contract = Kernel.get_in(registry_contract, ["services", "hello_service"])

    assert hello_contract != nil

    %Mesh.Contract.Delegate{destination: hello_destination} = hello_contract

    assert hello_destination == hello
  end

  test "can register service and receive contract notification" do
    {:ok, registry} = Mesh.Registry.start_link(%{})

    {:ok, hello} = GenServer.start_link(RegistryTest.Hello, nil)

    :ok = Mesh.subscribe_contract(registry) |> Mesh.Channel.subscribe(self(), :contract)

    :timer.sleep(50)

    :ok = Mesh.deep_call(registry, ["register"], %{
        "name" => "hello_service",
        "delegate" => %Mesh.Contract.Delegate{destination: hello}
    })

    receive do
      {:contract, registry_contract} ->
        assert registry_contract != nil

        hello_contract = Kernel.get_in(registry_contract, ["services", "hello_service"])

        assert hello_contract != nil

        %Mesh.Contract.Delegate{destination: hello_destination} = hello_contract

        assert hello_destination == hello
      msg ->
        assert {:contract, _} = msg
    after
      100 -> raise "expected message not received"
    end
  end

  test "can perform direct call across delegate boundary" do
    {:ok, registry} = Mesh.Registry.start_link(%{})

    {:ok, hello} = GenServer.start_link(RegistryTest.Hello, nil)

    :ok = Mesh.deep_call(registry, ["register"], %{
        "name" => "hello_service",
        "delegate" => %Mesh.Contract.Delegate{destination: hello}
    })

    assert Mesh.deep_call(
        registry,
        ["services", "hello_service", "methods", "hello"],
        %{"item" => "bar"}
      ) == "Hello, bar!"
  end

  test "can deregister" do
    {:ok, registry} = Mesh.Registry.start_link(%{})

    {:ok, hello} = GenServer.start_link(RegistryTest.Hello, nil)

    :ok = Mesh.deep_call(registry, ["register"], %{
        "name" => "hello_service",
        "delegate" => %Mesh.Contract.Delegate{destination: hello}
    })

    :ok = Mesh.deep_call(registry, ["deregister"], %{
        "name" => "hello_service",
    })

    registry_contract = Mesh.get_contract(registry)

    assert registry_contract != nil

    hello_contract = Kernel.get_in(registry_contract, ["services", "hello_service"])

    assert hello_contract == nil
  end

  test "service gets deregistered when it stops" do
    {:ok, registry} = Mesh.Registry.start_link(%{})

    {:ok, hello} = GenServer.start(RegistryTest.Hello, nil)

    :ok = Mesh.deep_call(registry, ["register"], %{
        "name" => "hello_service",
        "delegate" => %Mesh.Contract.Delegate{destination: hello}
    })

    assert catch_exit(GenServer.call(hello, :die)) != nil
    :timer.sleep(20)

    registry_contract = Mesh.get_contract(registry)

    assert registry_contract != nil

    hello_contract = Kernel.get_in(registry_contract, ["services", "hello_service"])

    assert hello_contract == nil
  end

  test "service gets deregistered when it crashes" do
    {:ok, registry} = Mesh.Registry.start_link(%{})

    {:ok, hello} = GenServer.start(RegistryTest.Hello, nil)

    :ok = Mesh.deep_call(registry, ["register"], %{
        "name" => "hello_service",
        "delegate" => %Mesh.Contract.Delegate{destination: hello}
    })

    assert catch_exit(GenServer.call(hello, :crash)) != nil
    :timer.sleep(20)

    registry_contract = Mesh.get_contract(registry)

    assert registry_contract != nil

    hello_contract = Kernel.get_in(registry_contract, ["services", "hello_service"])

    assert hello_contract == nil
  end
end