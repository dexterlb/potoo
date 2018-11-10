defmodule Potoo.Contract.Delegate do
  @moduledoc """
  Delegates are used to wrap bare pids. They are used in contracts to specify
  subservices - to delegate a subtree to another service.

  * :destination - the pid of the service we're delegating to
  * :data        - metadata associated with the delegate
  """

  alias Potoo.Contract

  @type t :: %__MODULE__{
    destination:  Contract.pidlike,
    data:         Contract.data
  }

  defstruct [
      destination: nil, data: %{}
  ]
end