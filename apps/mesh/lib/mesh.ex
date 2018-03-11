defmodule Mesh do
  @moduledoc """
  Documentation for Mesh.
  """

  alias Mesh.Contract
  alias Mesh.Contract.Type
  alias Mesh.Channel

  def call(function = %Contract.Function{}, argument) do
    call(function, argument, false)
  end

  def call(target, function = %Contract.Function{}, argument) do
    call(target, function, argument, false)
  end

  def call(function = %Contract.Function{pid: target}, argument, fuzzy) when is_boolean(fuzzy) do
    call(target, function, argument, fuzzy)
  end


  def call(nil, function = %Contract.Function{}, argument, fuzzy) when is_boolean(fuzzy) do
    call(function, argument, fuzzy)
  end


  def call(target, function = %Contract.Function{}, argument, true) do
    case Type.cast(argument, function.argument) do
      {:ok, correctly_typed_argument} -> call(target, function, correctly_typed_argument)
      {:fail, err}                    -> {:fail, err}
    end
  end

  def call(target, function = %Contract.Function{}, argument, false) do
    case check_argument(function, argument) do
      {:fail, err}  -> {:fail, err}
      :ok           ->
        check_retval(function, GenServer.call(target, {function.name, argument}))
    end
  end

  def unsafe_call(target, function_name, argument) do
    GenServer.call(target, {function_name, argument})
  end

  def direct_call(target, path, argument, fuzzy \\ false)
  def direct_call(target, path, argument, fuzzy) do
    contract = Mesh.get_contract(target)
    contract_call(target, contract, path, argument, fuzzy)
  end

  def contract_call(target, contract, path, argument, fuzzy \\ false)
  def contract_call(target, contract, [], argument, fuzzy) do
    call(target, contract, argument, fuzzy)
  end

  def contract_call(_, %Contract.Delegate{destination: new_target}, path, argument, fuzzy) do
    direct_call(new_target, path, argument, fuzzy)
  end

  def contract_call(target, contract = %{}, [key | rest], argument, fuzzy) do
    contract_call(target, Map.get(contract, key), rest, argument, fuzzy)
  end

  def contract_call(_, nil, _, _, _) do
    {:fail, "nil contract (probably obtained by wrong path?)"}
  end

  def get_contract(target) do
    GenServer.call(target, :contract) |> Contract.populate_pids(target)
  end

  def subscribe_contract(target) do
    GenServer.call(target, :subscribe_contract)
      |> Channel.map!(fn(con) -> Contract.populate_pids(con, target) end)
  end

  @doc """
  Checks if the given (concrete) argument matches the contract.
  """
  def check_argument(function, argument) do
    case Type.is_valid(function.argument) do
      false -> {:fail, "function argument type (#{inspect(function.argument)}) in contract is invalid"}
      true ->
        case Type.is_of(function.argument, argument) do
          false -> {:fail, "function argument (#{inspect(argument)}) doesn't match type in contract (#{inspect(function.argument)})"}
          true  -> :ok
        end
    end
  end

  defp check_retval(function, retval) do
    # todo: think about whether the convenience of returning retval instead
    # of {:ok, retval} is worth it

    case Type.is_valid(function.retval) do
      false ->
        {:fail, "function return value type (#{inspect(function.retval)}) in contract is invalid"}
      true ->
        case Type.is_of(function.retval, retval) do
          true -> retval
          false -> {:fail, "function return value doesn't match type in contract"}
        end
    end
  end
end
