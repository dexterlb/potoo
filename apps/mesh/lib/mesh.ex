defmodule Mesh do
  @moduledoc """
  Documentation for Mesh.
  """

  def call(target, function, argument) do
    case check_argument(function, argument) do
      {:fail, err}  -> {:fail, err}
      :ok           -> GenServer.call(target, {function.name, argument})
    end
  end

  def direct_call(target, path, argument) do
    contract = Mesh.get_contract(target)
    contract_call(target, contract, path, argument)
  end

  def contract_call(target, contract, [], argument) do
    call(target, contract, argument)
  end
  
  def contract_call(_, %Mesh.Contract.Delegate{destination: new_target}, path, argument) do
    direct_call(new_target, path, argument)
  end

  def contract_call(target, contract = %{}, [key | rest], argument) do
    contract_call(target, Map.get(contract, key), rest, argument)
  end

  def contract_call(_, nil, _, _) do
    raise "nil contract"
  end

  def get_contract(target) do
    GenServer.call(target, :contract)
  end

  @doc """
  Checks if the given (concrete) argument match the contract.
  """
  def check_argument(function, argument) do
    case Contract.Type.is_of(function.argument, argument) do
      false -> {:fail, "function argument don't match types in contract"}
      true  -> :ok
    end
  end
end
