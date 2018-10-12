defmodule GlobalRegistry.Clock do
  use GenServer
  require OK

  def start_link(registry, opts \\ []) do
    GenServer.start_link(__MODULE__, registry, opts)
  end

  def init(registry) do
    :ok = Mesh.deep_call(registry, ["register"], %{
        "name" => "clock_service",
        "delegate" => %Mesh.Contract.Delegate{destination: self()}
    })

    Process.send_after(self(), :tick, 100)

    OK.for do
      time_channel <- Mesh.Channel.start_link()
      is_utc_channel <- Mesh.Channel.start_link()
      contract_channel <- Mesh.Channel.start_link()
    after
      {:ok, %{
        time_channel: time_channel,
        is_utc_channel: is_utc_channel,
        contract_channel: contract_channel,
        is_utc: false
      }}
    end
  end

  @contract %{
    "description" => "Clock",
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
    },
    "is_utc" => %{
      "get" => %Mesh.Contract.Function{
        name: "is_utc.get",
        argument: nil,
        retval: :bool,
      },
      "subscribe" => %Mesh.Contract.Function{
        name: "is_utc.subscribe",
        argument: nil,
        retval: {:channel, :bool}
      },
      "set" => %Mesh.Contract.Function{
        name: "is_utc.set",
        argument: :bool,
        retval: nil
      }
    }
  }

  def handle_call(:contract, _from, state) do
    {:reply, @contract, state}
  end

  def handle_call(:subscribe_contract, _from, state = %{contract_channel: chan}) do
    {:reply, chan, state}
  end

  def handle_call({"time.get", nil}, _, state = %{is_utc: is_utc}) do
    {:reply, time(is_utc), state}
  end

  def handle_call({"time.subscribe", nil}, _, state = %{time_channel: time_channel}) do
    {:reply, time_channel, state}
  end

  def handle_call({"is_utc.get", nil}, _, state = %{is_utc: is_utc}) do
    {:reply, is_utc, state}
  end

  def handle_call({"is_utc.set", is_utc}, _, state = %{is_utc_channel: is_utc_channel}) do
    Mesh.Channel.send(is_utc_channel, is_utc)
    newstate = %{ state | is_utc: is_utc }
    tick(newstate)
    {:reply, nil, newstate}
  end

  def handle_call({"is_utc.subscribe", nil}, _, state = %{is_utc_channel: is_utc_channel}) do
    {:reply, is_utc_channel, state}
  end


  def handle_info(:tick, state) do
    tick(state)
    Process.send_after(self(), :tick, 1000)
    {:noreply, state}
  end

  defp tick(%{time_channel: time_channel, is_utc: is_utc}) do
    Mesh.Channel.send(time_channel, time(is_utc))
  end

  defp time(false) do
    "#{inspect(:calendar.local_time)}"
  end

  defp time(true) do
    "#{inspect(:calendar.universal_time)}"
  end
end
