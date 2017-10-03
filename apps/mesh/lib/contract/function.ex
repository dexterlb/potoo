defmodule Mesh.Contract.Function do
  defstruct [
      :name, args: %{}, retval: :void, data: %{}
  ]
end