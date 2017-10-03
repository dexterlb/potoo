defmodule Mesh do
  @moduledoc """
  Documentation for Mesh.
  """

  def call(target, function, arguments) do
    case check_arguments(function, arguments) do
      {:fail, err}  -> {:fail, err}
      :ok           -> GenServer.call(target, {function.name, arguments})
    end
  end

  def direct_call(target, path, arguments) do
    contract = Mesh.get_contract(target)
    contract_call(target, contract, path, arguments)
  end

  def contract_call(target, contract, [], arguments) do
    call(target, contract, arguments)
  end
  
  def contract_call(_, %Mesh.Contract.Delegate{destination: new_target}, path, arguments) do
    direct_call(new_target, path, arguments)
  end

  def contract_call(target, contract = %{}, [key | rest], arguments) do
    contract_call(target, Map.get(contract, key), rest, arguments)
  end

  def contract_call(_, nil, _, _) do
    raise "nil contract"
  end

  def get_contract(target) do
    GenServer.call(target, :contract)
  end

  @doc """
  Checks if the given (concrete) arguments match the contract.
  """
  def check_arguments(function, arguments) do
    arg_types = function.args
      |> Map.to_list
      |> Enum.map(fn({key, data}) -> {key, Map.get(data, "type")} end)
      |> Map.new

    case Contract.Type.is_of({:struct, arg_types}, arguments) do
      false -> {:fail, "function arguments don't match types in contract"}
      true  -> :ok
    end
  end
end
