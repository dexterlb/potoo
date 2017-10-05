defmodule Ui.PidCache do
  use GenServer

  def start_link(name, root) do
    GenServer.start_link(__MODULE__, {1, %{root => 0}, %{0 => root}}, name: name)
  end

  def get(cache_pid, pid_or_id) do
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
end