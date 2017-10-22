defmodule Mesh.ServerUtils.Json do
  alias Mesh.ServerUtils.PidCache

  def jsonify_contract(%Mesh.Contract.Function{name: name, argument: argument, retval: retval, data: data}, pc) do
    %{
      "__type__" => "function",
      "name" => name,
      "argument" => jsonify_contract(argument, pc),
      "retval" => jsonify_contract(retval, pc),
      "data" => data
    }
  end
  def jsonify_contract(%Mesh.Contract.Delegate{destination: destination, data: data}, pc) do
    %{
      "__type__" => "delegate",
      "destination" => PidCache.get(pc, {:delegate, destination}),
      "data" => data
    }
  end
  def jsonify_contract(contract = %{}, pc) do
    # todo: fix the case when there's a __key__ in the map
    contract |> Enum.map(fn({k, v}) -> {k, jsonify_contract(v, pc)} end) |> Map.new
  end
  def jsonify_contract(t, pc) when is_tuple(t) do
    t |> Tuple.to_list |> jsonify_contract(pc)
  end
  def jsonify_contract(l, pc) when is_list(l) do
    l |> Enum.map(fn(x) -> jsonify_contract(x, pc) end)
  end
  def jsonify_contract(a, _) when is_atom(a) do
    Atom.to_string(a)
  end
  def jsonify_contract(x, _), do: x
end