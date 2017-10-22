defmodule Mesh.ServerUtils.PidCache do
  use GenServer

  def start_link(opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, {0, %{}, %{}}, opts)
  end

  def get(cache_pid, target = {_, pid_or_id}) when is_pid(pid_or_id) or is_integer(pid_or_id) do
    GenServer.call(cache_pid, {:get, target})
  end

  def handle_call({:get, {bucket, pid}}, _from, {last_id, pid_to_id, id_to_pid}) when is_pid(pid) do
    case Map.get(pid_to_id, {bucket, pid}) do
      nil ->
        new_id = last_id + 1
        new_pid_to_id = Map.put(pid_to_id, {bucket, pid}, new_id)
        new_id_to_pid = Map.put(id_to_pid, {bucket, new_id}, pid)

        {:reply, new_id, {new_id, new_pid_to_id, new_id_to_pid}}

      id -> {:reply, id, {last_id, pid_to_id, id_to_pid}}
    end
  end

  def handle_call({:get, {bucket, id}}, _from, state = {_, _, id_to_pid}) when is_integer(id) do
    {:reply, Map.get(id_to_pid, {bucket, id}), state}
  end
end