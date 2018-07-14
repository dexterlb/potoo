defmodule Mesh.Cache do
  @moduledoc """
  This module can cache contracts of services.

  It provides a clean interface for calling functions by path (like
  `Mesh.deep_call/4`), but doesn't repeatedly get contracts on every request,
  so it's much faster.
  """

  use GenServer

  alias Mesh.Channel
  alias Mesh.Contract
  alias Mesh.Contract.Delegate
  alias Mesh.Contract.Function

  require OK

  @type t :: Contract.pidlike

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @spec get(t, Mesh.target, Mesh.path) :: {:ok, Contract.t} | {:error, String.t}
  @doc """
  This is the main functionality of the cache.
  Gets a contract object by a path in the tree under the given root service.
  The path may cross delegate boundaries.
  """
  def get(cache, root, path) do
    GenServer.call(cache, {:get, pid(root), path})
  end

  @spec subscribe(t, Mesh.target, Mesh.path) :: Channel.t
  @doc """
  Subscribes to a contract object. Updates will be sent each time
  it changes or when an intermediate contract in the path up to
  the object is changed. If an intermeiate contract disappears,
  silently waits for it to reappear.

  Kill the returned channel when the subscription is no more needed.
  """
  def subscribe(cache, root, path) do
    :not_implemented
  end

  @spec get_contract(t, Mesh.target) :: Contract.t
  @doc """
  Retreives the contract of the target service from the cache. If it's not
  present, calls `Mesh.get_contract/1` and stores it.
  """
  def get_contract(cache, target) do
    GenServer.call(cache, {:get_contract, pid(target)})
  end

  @spec subscribe_contract(t, Mesh.target) :: Channel.t
  @doc """
  Returns a channel which has been returned by a call of
  `Mesh.subscribe_contract/1` on the target service.
  """
  def subscribe_contract(cache, target) do
    GenServer.call(cache, {:subscribe_contract, pid(target)})
  end

  def call(cache, target, path, argument, fuzzy \\ false) do
    case get(cache, target, path) do
      {:ok, f = %Function{}} -> Mesh.call(nil, f, argument, fuzzy)
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

  def handle_call({:get, target, path}, _from, state = %{contracts: contracts}) do
    {contract, _chan, contracts_2} = attach_contract(target, contracts)
    {contracts_3, result} = deep_get(path, contract, contracts_2)
    {:reply, result, %{state | contracts: contracts_3}}
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
        chan = Mesh.subscribe_contract(target)
        :ok = Channel.subscribe(chan, self(), {:new_contract, target})
        contract = Mesh.get_contract(target)

        {contract, chan, Map.put(contracts, target, {contract, chan})}
    end
  end

  defp pid(%Delegate{destination: target}), do: target
  defp pid(pid) when is_pid(pid), do: pid
  defp pid(name) when is_atom(name), do: name  # todo: make this into a pid
  defp pid(target = {node, name}) when is_atom(node) and is_atom(name), do: target
end