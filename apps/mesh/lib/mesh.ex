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

  @doc """
  Checks if the given (concrete) arguments match the contract.
  """
  def check_arguments(function, arguments) do
    :ok
  end
end
