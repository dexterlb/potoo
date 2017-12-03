defmodule Mesh.ServerUtils.Json do
  alias Mesh.ServerUtils.PidCache

  def jsonify(%Mesh.Contract.Function{name: name, argument: argument, retval: retval, data: data}, pc) do
    %{
      "__type__" => "function",
      "name" => name,
      "argument" => jsonify(argument, pc),
      "retval" => jsonify(retval, pc),
      "data" => data
    }
  end
  def jsonify(nil, _), do: nil
  def jsonify(b, _) when is_boolean(b), do: b
  def jsonify(%Mesh.Contract.Delegate{destination: destination, data: data}, pc) do
    %{
      "__type__" => "delegate",
      "destination" => PidCache.get(pc, {:delegate, destination}),
      "data" => data
    }
  end
  def jsonify({Mesh.Channel, chan_pid}, pc) do
    %{
      "__type__" => "channel",
      "id" => PidCache.get(pc, {:channel, chan_pid})
    }
  end
  def jsonify(contract = %{}, pc) do
    # todo: fix the case when there's a __key__ in the map
    contract |> Enum.map(fn({k, v}) -> {jsonify(k, pc), jsonify(v, pc)} end) |> Map.new
  end
  def jsonify(t, pc) when is_tuple(t) do
    t |> Tuple.to_list |> jsonify(pc)
  end
  def jsonify(l, pc) when is_list(l) do
    l |> Enum.map(fn(x) -> jsonify(x, pc) end)
  end
  def jsonify(a, _) when is_atom(a) do
    Atom.to_string(a)
  end
  def jsonify(x, _), do: x
end