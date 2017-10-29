defmodule Mesh.ServerUtils.PidCache do
  use GenServer
  require Logger

  def start_link(initial_contents \\ [], opts \\ [name: __MODULE__]) do
    pid_to_id = initial_contents
      |> Enum.map(fn({bucket, pid, id}) -> {{bucket, pid}, id} end)
      |> Map.new
    id_to_pid = initial_contents
      |> Enum.map(fn({bucket, pid, id}) -> {{bucket, id}, pid} end)
      |> Map.new
    id_to_data = initial_contents
      |> Enum.map(fn({bucket, _pid, id}) -> {{bucket, id}, nil} end)
      |> Map.new
    last_id = initial_contents
      |> Enum.map(fn({_, _, id}) -> id end)
      |> Enum.max(fn() -> -1 end)

    GenServer.start_link(__MODULE__, {last_id, pid_to_id, id_to_pid, id_to_data}, opts)
  end

  def get(cache_pid, target = {_, pid_or_id}) when is_pid(pid_or_id) or is_integer(pid_or_id) do
    GenServer.call(cache_pid, {:get, target})
  end

  def drop(cache_pid, target = {_, pid_or_id}) when is_pid(pid_or_id) or is_integer(pid_or_id) do
    GenServer.cast(cache_pid, {:drop, target})
  end

  def set_data(cache_pid, target = {_, pid_or_id}, data) when is_pid(pid_or_id) or is_integer(pid_or_id) do
    GenServer.call(cache_pid, {:set_data, target, data})
  end

  def get_data(cache_pid, target = {_, pid_or_id}, fun \\ fn(x) -> x end) when is_pid(pid_or_id) or is_integer(pid_or_id) do
    GenServer.call(cache_pid, {:get_data, target, fun})
  end

  def handle_call({:get, {bucket, pid}}, _from, {last_id, pid_to_id, id_to_pid, id_to_data}) when is_pid(pid) do
    case Map.get(pid_to_id, {bucket, pid}) do
      nil ->
        new_id = last_id + 1

        Logger.debug fn ->
          "adding pid #{inspect({bucket, new_id, pid})} to cache #{inspect(self())}"
        end

        new_pid_to_id = Map.put(pid_to_id, {bucket, pid}, new_id)
        new_id_to_pid = Map.put(id_to_pid, {bucket, new_id}, pid)

        remote_monitor(pid, bucket)

        {:reply, new_id, {new_id, new_pid_to_id, new_id_to_pid, id_to_data}}

      id -> {:reply, id, {last_id, pid_to_id, id_to_pid, id_to_data}}
    end
  end

  def handle_call({:get, {bucket, id}}, _from, state = {_, _, id_to_pid, _}) when is_integer(id) do
    {:reply, Map.get(id_to_pid, {bucket, id}), state}
  end

  def handle_call(
    {:set_data, {bucket, id}, data},
    _from,
    state = {last_id, pid_to_id, id_to_pid, id_to_data}
  ) do
    case Map.has_key?(id_to_pid, {bucket, id}) do
      true -> {
        :reply,
        true,
        {
          last_id, pid_to_id, id_to_pid,
          Map.put(id_to_data, {bucket, id}, data)
        }
      }
      false -> {:reply, false, state}
    end
  end

  def handle_call(
    {:get_data, {bucket, id}, fun},
    _from,
    state = {_, _, _, id_to_data}
  ) do
    reply = case Map.fetch(id_to_data, {bucket, id}) do
      {:ok, data} -> fun.(data)
      _ -> nil
    end
    {:reply, reply, state}
  end

  def handle_cast({:drop, {bucket, pid}}, state = {last_id, pid_to_id, id_to_pid, id_to_data}) do
    case Map.get(pid_to_id, {bucket, pid}) do
      nil -> {:noreply, state}
      id ->
        Logger.debug fn ->
          "dropping pid #{inspect({bucket, id, pid})} from cache #{inspect(self())}"
        end
        new_pid_to_id = Map.delete(pid_to_id, {bucket, pid})
        new_id_to_pid = Map.delete(id_to_pid, {bucket, id})
        new_id_to_data = Map.delete(id_to_data, {bucket, id})

        {:noreply, {last_id, new_pid_to_id, new_id_to_pid, new_id_to_data}}
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