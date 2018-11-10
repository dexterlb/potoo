defmodule Potoo.Cache do
  @moduledoc """
  This module can cache contracts of services.

  It provides a clean interface for calling functions by path (like
  `Potoo.deep_call/4`), but doesn't repeatedly get contracts on every request,
  so it's much faster.
  """

  use GenServer

  alias Potoo.Channel
  alias Potoo.Contract
  alias Potoo.Contract.Delegate
  alias Potoo.Contract.Function
  alias Potoo.Cache

  require OK

  @type t :: Contract.pidlike

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @doc """
  This is the main functionality of the cache.
  Gets a contract object by a path in the tree under the given root service.
  The path may cross delegate boundaries.
  """
  @spec get(t, Potoo.target, Potoo.path) :: {:ok, Contract.t} | {:error, String.t}
  def get(cache, root, path) do
    {_, result} = GenServer.call(cache, {:probe, pid(root), path})
    result
  end

  @doc """
  This is mainly for debugging or internal purposes.

  Same as `get/3`, but returns all encountered valid contracts.
  """
  @spec probe(t, Potoo.target, Potoo.path) :: {%{Potoo.target => Contract.t}, {:ok, Contract.t} | {:error, String.t}}
  def probe(cache, root, path) do
    {raw_contracts, result} = GenServer.call(cache, {:probe, pid(root), path})
    contracts = raw_contracts
      |> Enum.map(fn({target, {contract, _}}) -> {target, contract} end)
      |> Map.new
    {contracts, result}
  end

  @spec subscribe(t, Potoo.target, Potoo.path) :: Channel.t
  @doc """
  Subscribes to a contract object. Updates will be sent each time
  it changes or when an intermediate contract in the path up to
  the object is changed. If an intermeiate contract disappears,
  silently waits for it to reappear.

  Kill the returned channel when the subscription is no more needed.
  """
  def subscribe(cache, root, path) do
    {:ok, chan} = Channel.start()
    {:ok, _} = Cache.Subscriber.start(cache, root, path, chan)
    chan
  end

  @spec get_contract(t, Potoo.target) :: Contract.t
  @doc """
  Retreives the contract of the target service from the cache. If it's not
  present, calls `Potoo.get_contract/1` and stores it.
  """
  def get_contract(cache, target) do
    GenServer.call(cache, {:get_contract, pid(target)})
  end

  @spec subscribe_contract(t, Potoo.target) :: Channel.t
  @doc """
  Returns a channel which has been returned by a call of
  `Potoo.subscribe_contract/1` on the target service.
  """
  def subscribe_contract(cache, target) do
    GenServer.call(cache, {:subscribe_contract, pid(target)})
  end

  def call(cache, target, path, argument, fuzzy \\ false) do
    case get(cache, target, path) do
      {:ok, f = %Function{}} -> Potoo.call(nil, f, argument, fuzzy)
      {:ok, t} -> {:error, "Trying to call non-function object: #{inspect(t)}"}
      {:error, err} -> {:error, err}
    end
  end

  def init(nil) do
    state = %{
      contracts: %{}
    }

    {:ok, state}
  end

  def handle_call({:get_contract, target}, _from, state = %{contracts: contracts}) do
    {contract, _chan, new_contracts} = attach_contract(target, contracts)
    {:reply, contract, %{state | contracts: new_contracts}}
  end

  def handle_call({:subscribe_contract, target}, _from, state = %{contracts: contracts}) do
    {_contract, chan, new_contracts} = attach_contract(target, contracts)
    {:reply, chan, %{state | contracts: new_contracts}}
  end

  def handle_call({:probe, target, path}, _from, state = %{contracts: contracts}) do
    {contract, _chan, contracts_2} = attach_contract(target, %{})
    {contracts_3, result} = deep_get(path, contract, contracts_2)
    {:reply, {contracts_3, result}, %{state | contracts: Map.merge(contracts, contracts_3)}}
  end

  def handle_info({{:new_contract, target}, contract}, state = %{contracts: contracts}) do
    {:noreply, %{
      state |
        contracts: Map.update!(contracts, target, fn({_, chan}) -> {contract, chan} end) }
    }
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
    forget(pid, state)
  end

  defp forget(target, state = %{contracts: contracts}) do
    {:noreply, %{ state | contracts: Map.delete(contracts, target) }}
  end

  defp deep_get([], contract, contracts) do
    {contracts, {:ok, contract}}
  end

  defp deep_get(path, %Delegate{destination: target}, contracts) do
    {contract, _chan, new_contracts} = attach_contract(target, contracts)
    deep_get(path, contract, new_contracts)
  end

  defp deep_get([key | path], contract = %{}, contracts) do
    case Map.fetch(contract, key) do
      :error -> {contracts, {:error, "no such key: #{inspect(key)} in map #{inspect(contract)}"}}
      {:ok, subcontract} -> deep_get(path, subcontract, contracts)
    end
  end

  defp deep_get([index | path], contract, contracts) when is_list(contract) and is_number(index) do
    case Enum.fetch(contract, index) do
      :error -> {contracts, {:error, "no such index #{inspect(index)}"}}
      {:ok, subcontract} -> deep_get(path, subcontract, contracts)
    end
  end

  defp attach_contract(target, contracts) do
    case Map.fetch(contracts, target) do
      {:ok, {contract, chan}} -> {contract, chan, contracts}
      :error ->
        Process.monitor(target)
        chan = Potoo.subscribe_contract(target)
        :ok = Channel.subscribe(chan, self(), {:new_contract, target})
        contract = Potoo.get_contract(target)

        {contract, chan, Map.put(contracts, target, {contract, chan})}
    end
  end

  defp pid(%Delegate{destination: target}), do: target
  defp pid(pid) when is_pid(pid), do: pid
  defp pid(name) when is_atom(name), do: name  # todo: make this into a pid
  defp pid(target = {node, name}) when is_atom(node) and is_atom(name), do: target
end