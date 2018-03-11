defmodule Mesh.Contract do
  @moduledoc """
  Contracts are the main building blocks of services. Each service provides a
  contract which specifies all callable functions.

  The contract is a tree-like structure composed of the following nodes:

  - primitive (leaf) nodes
      - basic values (ints, strings, atoms etc)
      - functions
      - delegates
    - branching nodes
      - maps
      - lists
  """

  alias Mesh.Contract.Function

  @doc """
  Sets the pids of any pidless functions in the contract to the given pid
  """
  def populate_pids(contract, pid)

  def populate_pids(f = %Function{pid: nil}, pid) do
    %Function{ f | pid: pid }
  end

  def populate_pids(contract = %{__struct__: _}, _), do: contract

  def populate_pids(map, pid) when is_map(map) do
    Enum.map(map, fn({k, v}) -> {k, populate_pids(v, pid)} end) |> Map.new
  end

  def populate_pids(list, pid) when is_list(list) do
    Enum.map(list, fn(v) -> populate_pids(v, pid) end)
  end

  def populate_pids(contract, _), do: contract
end