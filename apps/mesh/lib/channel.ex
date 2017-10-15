defmodule Mesh.Channel do
  use GenServer

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

  def send({__MODULE__, channel}, message) do
    GenServer.cast(channel, {:send, message})
  end

  def handle_call({:subscribe, pid, token}, _from, subscribers) do
    {:reply, :ok, Map.put(subscribers, pid, token)}
  end

  def handle_cast({:send, message}, subscribers) do
    subscribers |> Enum.map(fn(target) -> dispatch(target, message) end)

    {:noreply, subscribers}
  end

  defp dispatch({pid, token}, message) do
    Kernel.send(pid, {token, message})
  end
end