defmodule Ui.PidCache do
  use GenServer

  def start_link(name, root) do
    GenServer.start_link(__MODULE__, {0, %{root => 0}, %{0 => root}}, name: name)
  end

  def get(cache_pid, pid_or_id) when is_pid(pid_or_id) or is_integer(pid_or_id) do
    GenServer.call(cache_pid, {:get, pid_or_id})
  end

  def handle_call({:get, pid}, _from, {last_id, pid_to_id, id_to_pid}) when is_pid(pid) do
    case Map.get(pid_to_id, pid) do
      nil ->
        new_id = last_id + 1
        new_pid_to_id = Map.put(pid_to_id, pid, new_id)
        new_id_to_pid = Map.put(id_to_pid, new_id, pid)

        {:reply, new_id, {new_id, new_pid_to_id, new_id_to_pid}}

      id -> {:reply, id, {last_id, pid_to_id, id_to_pid}}
    end
  end

  def handle_call({:get, id}, _from, state = {_, _, id_to_pid}) when is_integer(id) do
    {:reply, Map.get(id_to_pid, id), state}
  end

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
      "destination" => get(pc, destination),
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