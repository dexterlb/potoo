defmodule Mesh.ServerUtils.PidCache do
  use GenServer

  def start_link(initial_contents \\ [], opts \\ [name: __MODULE__]) do
    pid_to_id = initial_contents
      |> Enum.map(fn({bucket, pid, id}) -> {{bucket, pid}, id} end)
      |> Map.new
    id_to_pid = initial_contents
      |> Enum.map(fn({bucket, pid, id}) -> {{bucket, id}, pid} end)
      |> Map.new
    last_id = initial_contents
      |> Enum.map(fn({_, _, id}) -> id end)
      |> Enum.max(fn() -> -1 end)

    GenServer.start_link(__MODULE__, {last_id, pid_to_id, id_to_pid}, opts)
  end

  def get(cache_pid, target = {_, pid_or_id}) when is_pid(pid_or_id) or is_integer(pid_or_id) do
    GenServer.call(cache_pid, {:get, target})
  end

  def drop(cache_pid, target = {_, pid_or_id}) when is_pid(pid_or_id) or is_integer(pid_or_id) do
    GenServer.cast(cache_pid, {:drop, target})
  end

  def handle_call({:get, {bucket, pid}}, _from, {last_id, pid_to_id, id_to_pid}) when is_pid(pid) do
    case Process.alive?(pid) do
      true -> 
        case Map.get(pid_to_id, {bucket, pid}) do
          nil ->
            new_id = last_id + 1
            new_pid_to_id = Map.put(pid_to_id, {bucket, pid}, new_id)
            new_id_to_pid = Map.put(id_to_pid, {bucket, new_id}, pid)

            remote_monitor(pid, bucket)

            {:reply, new_id, {new_id, new_pid_to_id, new_id_to_pid}}

          id -> {:reply, id, {last_id, pid_to_id, id_to_pid}}
        end
      false -> {:reply, nil, {last_id, pid_to_id, id_to_pid}}
    end
  end

  def handle_call({:get, {bucket, id}}, _from, state = {_, _, id_to_pid}) when is_integer(id) do
    {:reply, Map.get(id_to_pid, {bucket, id}), state}
  end

  def handle_cast({:drop, {bucket, pid}}, state = {last_id, pid_to_id, id_to_pid}) do
    case Map.get(pid_to_id, {bucket, pid}) do
      nil -> {:noreply, state}
      id ->
        new_pid_to_id = Map.delete(pid_to_id, {bucket, pid})
        new_id_to_pid = Map.delete(id_to_pid, {bucket, id})

        {:noreply, {last_id, new_pid_to_id, new_id_to_pid}}
    end
  end

  defp remote_monitor(target, bucket) do
    from = self()

    spawn_link(
      fn() ->
        Process.monitor(target)
        receive_downs(from, bucket)
      end
    )
  end

  defp receive_downs(from, bucket) do
    receive do
      {:DOWN, _, :process, pid, _} -> 
        GenServer.cast(from, {:drop, {bucket, pid}})
      _ ->
        receive_downs(from, bucket)
    end
  end
end