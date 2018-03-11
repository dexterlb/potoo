defmodule Mesh.Contract.Function do
  defstruct [
      :name, pid: nil, argument: nil, retval: nil, data: %{}
  ]
end