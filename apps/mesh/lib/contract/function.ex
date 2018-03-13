defmodule Mesh.Contract.Function do
  @moduledoc """
  Function is a callable handle tied to a service.
  It may or may not contain a concrete service's pid.

  * :name     - the symbol by which this function is called on its service.
  in practice, if the handler is `handle_call({:foo, argument}, _, _)`,
  :foo is the name of the function
  * :pid      - the pid of the service. It may be nil - then the function is not
  tied to a concrete service, and a separate pid needs to be passed
  to `call`.
  * :argument - the argument's type. Functions have just one argument for
  simplicity, but it may be a very complex type.
  * :retval   - the return value's type.
  * :data     - extra metadata associated with the function
  """

  alias Mesh.Contract
  alias Mesh.Contract.Type

  @type t :: %__MODULE__{
    name:     call_handle,
    pid:      Contract.pidlike,
    argument: Type.t,
    retval:   Type.t,
    data:     Contract.data
  }

  @type call_handle :: atom | String.t

  defstruct [
      :name, pid: nil, argument: nil, retval: nil, data: %{}
  ]
end