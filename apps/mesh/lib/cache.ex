defmodule Mesh.Cache do
  @moduledoc """
  This module can cache contracts of services.

  It provides a clean interface for calling functions by path (like
  `Mesh.deep_call/4`), but doesn't repeatedly get contracts on every request,
  so it's much faster.
  """

  use GenServer

  require OK

  def init() do
    state = %{
      contracts: %{}
    }

    {:ok, state}
  end
end