defmodule Potoo.Cache.Subscriber do
  use GenServer

  alias Potoo.Cache
  alias Potoo.Channel

  def start(cache, root, path, chan) do
    restart(%{
      cache: cache,
      root: root,
      path: path,
      chan: chan
    })
  end

  defp restart(state) do
    GenServer.start(__MODULE__, state)
  end

  def init(state = %{cache: cache, chan: chan, root: root, path: path}) do
    Process.link(Channel.pid(chan))
    Process.monitor(Channel.pid(chan))
    Process.monitor(cache)  # need to die when the cache dies

    {contracts, result} = Cache.probe(cache, root, path)
    Enum.map(contracts, fn({target, _}) ->
      chan = Potoo.subscribe_contract(target)
      :ok = Channel.subscribe(chan, self(), {:new_contract, target})
    end)

    case result do
      {:ok, contract} -> Channel.send(chan, contract)
      _ -> :ok
    end
    {:ok, state}
  end

  def handle_info({{:new_contract, _target}, _contract}, state) do
    restart(state)
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, _, :process, _pid, _}, state) do
    {:stop, {:shutdown, :related_died}, state}
  end
end