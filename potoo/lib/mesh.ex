defmodule Potoo do
  @moduledoc """
  This module handles calling functions on services.
  """

  alias Potoo.Contract
  alias Potoo.Contract.Type
  alias Potoo.Contract.Function
  alias Potoo.Contract.Delegate
  alias Potoo.Channel

  @type return_value :: {:ok, term} | {:error, String.t}
  @type target       :: Contract.pidlike | Delegate.t
  @type path         :: [Contract.key]

  def call(function = %Contract.Function{}, argument) do
    call(nil, function, argument, false)
  end

  def call(target, function, argument, fuzzy \\ false)

  def call(target, function = %Contract.Function{}, argument, true) do
    case Type.cast(argument, function.argument) do
      {:ok, correctly_typed_argument} ->
        check_retval(function, unsafe_call(target, function, correctly_typed_argument))
      {:error, err}                    -> {:error, err}
    end
  end

  def call(target, function = %Contract.Function{}, argument, false) do
    case check_argument(function, argument) do
      {:error, err}  -> {:error, err}
      :ok           ->
        check_retval(function, unsafe_call(target, function, argument))
    end
  end

  @doc """
  Call a function without taking any note of its argument and return types.
  They may even be missing!

  Of course, if malformed data is supplied, this will not be checked and will
  probably crash the service. On the other hand, `unsafe_call/2` may be faster
  than `call/2`.

  Use with care.
  """
  @spec unsafe_call(Function.t, term) :: term
  def unsafe_call(function_with_pid, argument)
  def unsafe_call(%Function{name: name, pid: target}, argument) do
    unsafe_call(target, name, argument)
  end

  @doc """
  Same as `call/2`, but works on pidless functions (calls them on the given pid)
  """
  @spec unsafe_call(target, Function.t, term) :: term
  def unsafe_call(target, function, argument)
  def unsafe_call(%Delegate{destination: target}, function, argument) do
    unsafe_call(target, function, argument)
  end
  def unsafe_call(target, %Function{name: name, pid: nil}, argument) do
    unsafe_call(target, name, argument)
  end
  def unsafe_call(_, %Function{name: name, pid: target}, argument) do
    unsafe_call(target, name, argument)
  end
  def unsafe_call(target, function_name, argument) do
    GenServer.call(target, {function_name, argument})
  end

  def deep_call(target, path, argument, fuzzy \\ false)

  def deep_call(target, path, argument, fuzzy) do
    contract = Potoo.get_contract_pidless(target)
    contract_call(target, contract, path, argument, fuzzy)
  end

  defp contract_call(target, contract, [], argument, fuzzy) do
    call(target, contract, argument, fuzzy)
  end

  defp contract_call(_, %Contract.Delegate{destination: new_target}, path, argument, fuzzy) do
    deep_call(new_target, path, argument, fuzzy)
  end

  defp contract_call(target, contract = %{}, [key | rest], argument, fuzzy) do
    contract_call(target, Map.get(contract, key), rest, argument, fuzzy)
  end

  defp contract_call(target, contract, [index | rest], argument, fuzzy) when is_list(contract) do
    contract_call(target, Enum.at(contract, index), rest, argument, fuzzy)
  end

  defp contract_call(_, nil, _, _, _) do
    {:error, "nil contract (probably obtained by wrong path?)"}
  end

  def get_contract(target) do
    get_contract_pidless(target) |> Contract.populate_pids(target)
  end

  def get_contract_pidless(target) do
    GenServer.call(target, :contract)
  end

  def subscribe_contract(target) do
    subscribe_contract_pidless(target)
      |> Channel.map!(fn(con) -> Contract.populate_pids(con, target) end)
  end

  def subscribe_contract_pidless(target) do
    GenServer.call(target, :subscribe_contract)
  end

  @doc """
  Checks if the given (concrete) argument matches the contract.
  """
  def check_argument(function, argument) do
    case Type.is_valid(function.argument) do
      false -> {:error, "function argument type (#{inspect(function.argument)}) in contract is invalid"}
      true ->
        case Type.is_of(function.argument, argument) do
          false -> {:error, "function argument (#{inspect(argument)}) doesn't match type in contract (#{inspect(function.argument)})"}
          true  -> :ok
        end
    end
  end

  defp check_retval(function, retval) do
    # todo: think about whether the convenience of returning retval instead
    # of {:ok, retval} is worth it

    case Type.is_valid(function.retval) do
      false ->
        {:error, "function return value type (#{inspect(function.retval)}) in contract is invalid"}
      true ->
        case Type.is_of(function.retval, retval) do
          true -> retval
          false -> {:error, "function return value doesn't match type in contract"}
        end
    end
  end
end
