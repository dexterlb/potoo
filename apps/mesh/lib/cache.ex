defmodule Mesh.Cache do
  @moduledoc """
  This module can cache contracts of services.

  It provides a clean interface for calling functions by path (like
  `Mesh.deep_call/4`), but doesn't repeatedly get contracts on every request,
  so it's much faster.
  """

  use GenServer

  require OK

  def init(root) do
    OK.for do
      root_contract <- Mesh.get_contract(root)
      state = %{
        root: root,
        contracts: %{root => root_contract}
      }
    after
      {:ok, state}
    end
  end
end