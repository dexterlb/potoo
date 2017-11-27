defmodule GlobalRegistry.Hello do
  use GenServer

  def start_link(registry, opts \\ []) do
    GenServer.start_link(__MODULE__, registry, opts)
  end

  def init(registry) do
    result = Mesh.direct_call(registry, ["register"], %{
        "name" => "hello_service", 
        "delegate" => %Mesh.Contract.Delegate{destination: self()}
    })

    case result do
      :ok -> {:ok, nil}
      err -> err
    end
  end

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
    {:ok, chan} = Mesh.Channel.start_link()
    {:reply, chan, state}
  end

  def handle_call({"methods.hello", %{"item" => item}}, _, state) do
    {:reply, "Hello, #{item}!", state}
  end
end