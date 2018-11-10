defmodule PotooGlobalRegistry.Hello do
  use GenServer
  require OK

  def start_link(registry, opts \\ []) do
    GenServer.start_link(__MODULE__, registry, opts)
  end

  def init(registry) do
    OK.for do
      :ok = Potoo.deep_call(registry, ["register"], %{
          "name" => "hello_service",
          "delegate" => %Potoo.Contract.Delegate{destination: self()}
      })

      boing_chan <- Potoo.Channel.start_link()
    after
      %{boing_value: 4, boing_chan: boing_chan}
    end
  end

  @contract %{
    "description" => "A service which provides a greeting.",
    "methods" => %{
      "hello" => %Potoo.Contract.Function{
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
      "boing" => %{
        "action" => %Potoo.Contract.Function{
          name: "boing",
          argument: nil,
          retval: nil,
        },
      },
      "boinger" => %{
        "get" => %Potoo.Contract.Function{
          name: "boinger.get",
          argument: nil,
          retval: {:type, :float, %{
            "min" => 0,
            "max" => 20,
          }}
        },
        "subscribe" => %Potoo.Contract.Function{
          name: "boinger.subscribe",
          argument: nil,
          retval: {:channel, {:type, :float, %{
            "min" => 0,
            "max" => 20,
          }}}
        },
      }
    }

  }

  def handle_call(:contract, _from, state) do
    {:reply, @contract, state}
  end

  def handle_call(:subscribe_contract, _from, state) do
    {:ok, chan} = Potoo.Channel.start_link()
    {:reply, chan, state}
  end

  def handle_call({"methods.hello", %{"item" => item}}, _, state) do
    {:reply, "Hello, #{item}!", state}
  end

  def handle_call({"boing", nil}, _, state = %{boing_value: v, boing_chan: boing_chan}) do
    new = rem(v + 1, 21)
    Potoo.Channel.send(boing_chan, new)
    {:reply, nil, %{state | boing_value: new}}
  end

  def handle_call({"boinger.get", nil}, _, state = %{boing_value: v}) do
    {:reply, v, state}
  end

  def handle_call({"boinger.subscribe", nil}, _, state = %{boing_chan: boing_chan}) do
    {:reply, boing_chan, state}
  end
end
