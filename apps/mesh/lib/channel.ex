defmodule Mesh.Channel do
  use GenServer

  require Logger

  defmacro is_channel(value) do
    quote do
      (
        is_tuple(unquote(value)) and
        tuple_size(unquote(value)) == 2 and
        elem(unquote(value), 0) == Mesh.Channel and
        is_pid(elem(unquote(value), 1))
      )
    end
  end

  def start_link(opts \\ []) do
    case GenServer.start_link(__MODULE__, %{}, opts) do
      {:ok, pid} -> {:ok, {__MODULE__, pid}}
      err        -> err
    end
  end

  def subscribe({__MODULE__, channel}, pid, token) do
    GenServer.call(channel, {:subscribe, pid, token})
  end

  def unsubscribe({__MODULE__, channel}, pid) do
    GenServer.cast(channel, {:unsubscribe, pid})
  end

  def unsubscribe({__MODULE__, channel}, pid, token) do
    GenServer.cast(channel, {:unsubscribe, pid, token})
  end

  def send({__MODULE__, channel}, message) do
    GenServer.cast(channel, {:send, message})
  end

  def handle_call({:subscribe, pid, token}, _from, subscribers) do
    Logger.debug fn ->
      "subscribing pid #{inspect(pid)} to channel #{inspect(self())}"
    end

    Process.monitor(pid)

    new_subscribers = Map.update(
      subscribers, pid, MapSet.new([token]),
      fn(tokens) -> MapSet.put(tokens, token) end
    )

    {:reply, :ok, new_subscribers}
  end

  def handle_cast({:send, message}, subscribers) do
    subscribers |> Enum.map(fn(target) -> dispatch(target, message) end)

    {:noreply, subscribers}
  end

  def handle_cast({:unsubscribe, pid}, subscribers) do
    Logger.debug fn ->
      "unsubscribing pid #{inspect(pid)} from channel #{inspect(self())}"
    end
    {:noreply, Map.delete(subscribers, pid)}
  end

  def handle_cast({:unsubscribe, pid, token}, subscribers) do
    Logger.debug fn ->
      "unsubscribing pid #{inspect(pid)} from channel #{inspect(self())} with token #{inspect(token)}"
    end

    tokens = Map.get(subscribers, pid, MapSet.new())
      |> MapSet.delete(token)
    
    new_subscribers = case MapSet.size(tokens) do
      0 -> Map.delete(subscribers, pid)
      _ -> Map.put(subscribers, pid, tokens)
    end

    {:noreply, new_subscribers}
  end

  def handle_info({:DOWN, _, :process, pid, _}, subscribers) do
    handle_cast({:unsubscribe, pid}, subscribers)
  end

  defp dispatch({pid, tokens}, message) do
    tokens |> Enum.map(fn(token) ->
      Kernel.send(pid, {token, message})
    end)
  end
end