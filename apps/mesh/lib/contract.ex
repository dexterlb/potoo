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
  alias Mesh.Contract.Delegate

  @type t               :: value | contract_list | contract_map | Function.t | Delegate.t
  @type value           :: String.t | atom | nil | float | integer
  @type contract_list   :: [t]
  @type contract_map    :: %{required(key) => t}
  @type key             :: String.t | atom

  @type pidlike :: pid | port | atom | {atom, node}

  @type data :: %{required(key) => data} | [data] | value

  @spec populate_pids(t, pidlike) :: t
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

  def property(type, name, methods \\ [:set, :get, :subscribe], subcontract \\ %{}) do
    methods
      |> Enum.map(fn(method) -> make_method(method, type, name) end)
      |> Enum.reduce(subcontract, &Map.merge/2)
  end

  defp make_method(:set, type, name) do
    %{ "set" => %Function{
      name: "#{name}.set",
      argument: type,
      retval: nil,
    }}
  end

  defp make_method(:get, type, name) do
    %{ "get" => %Function{
      name: "#{name}.get",
      argument: nil,
      retval: type,
    }}
  end

  defp make_method(:subscribe, type, name) do
    %{ "subscribe" => %Function{
      name: "#{name}.subscribe",
      argument: nil,
      retval: {:channel, type},
    }}
  end
end
