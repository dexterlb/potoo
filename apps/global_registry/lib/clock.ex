defmodule GlobalRegistry.Clock do
  use GenServer

  def start_link(registry, opts \\ []) do
    GenServer.start_link(__MODULE__, registry, opts)
  end

  def init(registry) do
    result = Mesh.direct_call(registry, ["register"], %{
        "name" => "clock_service", 
        "delegate" => %Mesh.Contract.Delegate{destination: self()}
    })

    Process.send_after(self(), :tick, 100)

    {:ok, chan} = Mesh.Channel.start_link()

    case result do
      :ok -> {:ok, chan}
      err -> err
    end
  end

  @contract %{
    "description" => "A service which provides accurate time.",
    "time" => %{
      "get" => %Mesh.Contract.Function{
        name: "time.get",
        argument: nil,
        retval: :string,
      },
      "subscribe" => %Mesh.Contract.Function{
        name: "time.subscribe",
        argument: nil,
        retval: {:channel, :string}
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

  def handle_call({"time.get", nil}, _, state) do
    {:reply, time(), state}
  end

  def handle_call({"time.subscribe", nil}, _, chan) do
    {:reply, chan, chan}
  end

  def handle_info(:tick, chan) do
    Mesh.Channel.send(chan, time())
    Process.send_after(self(), :tick, 1000)
    {:noreply, chan}
  end

  defp time do
    "Erlang time: #{inspect(:calendar.local_time)}"
  end
end