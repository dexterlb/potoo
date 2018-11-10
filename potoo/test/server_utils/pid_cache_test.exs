defmodule PidCacheTest do
  use ExUnit.Case
  doctest Potoo.ServerUtils.PidCache

  alias Potoo.ServerUtils.PidCache

  test "can put and retreive a pid" do
    {:ok, pc} = PidCache.start_link()

    proc = spawn_link(&dummy/0)

    id = PidCache.get(pc, {:my_pids, proc})

    proc2 = PidCache.get(pc, {:my_pids, id})

    assert is_pid(proc2)
    assert proc == proc2
    assert is_integer(id)
  end

  test "can put and fetch a pid" do
    {:ok, pc} = PidCache.start_link()

    proc = spawn_link(&dummy/0)

    {:ok, id} = PidCache.fetch(pc, {:my_pids, proc})

    {:ok, proc2} = PidCache.fetch(pc, {:my_pids, id})

    assert is_pid(proc2)
    assert proc == proc2
    assert is_integer(id)
  end

  test "getting non-existant id yields nil" do
    {:ok, pc} = PidCache.start_link()

    assert PidCache.get(pc, {:my_pids, 42}) == nil
  end

  test "fetching non-existant id yields error" do
    {:ok, pc} = PidCache.start_link()

    assert {:error, _} = PidCache.fetch(pc, {:my_pids, 42})
  end

  test "putting the same pid twice yields the same id" do
    {:ok, pc} = PidCache.start_link()

    proc = spawn_link(&dummy/0)

    id1 = PidCache.get(pc, {:my_pids, proc})

    id2 = PidCache.get(pc, {:my_pids, proc})

    assert id1 == id2
  end

  test "can drop by pid" do 
    {:ok, pc} = PidCache.start_link()

    proc = spawn_link(&dummy/0)

    id = PidCache.get(pc, {:my_pids, proc})

    PidCache.drop(pc, {:my_pids, proc})

    :timer.sleep(50)

    assert PidCache.get(pc, {:my_pids, id}) == nil
  end

  test "pid is only kept until process dies" do
    {:ok, pc} = PidCache.start_link()

    proc = spawn_link(&dummy/0)

    id = PidCache.get(pc, {:my_pids, proc})

    assert PidCache.get(pc, {:my_pids, id}) == proc

    send(proc, :foo)

    :timer.sleep(50)

    assert PidCache.get(pc, {:my_pids, id}) == nil
  end

  test "can initialise with a pid" do
    proc = spawn_link(&dummy/0)
    {:ok, pc} = PidCache.start_link([{:my_pids, proc, 42}])

    assert PidCache.get(pc, {:my_pids, 42}) == proc
  end

  test "can initialise with a dead pid" do
    proc = spawn_link(fn() -> nil end)
    {:ok, pc} = PidCache.start_link([{:my_pids, proc, 42}])

    assert PidCache.get(pc, {:my_pids, 42}) == proc
  end

  defp dummy() do
    receive do
      _ -> nil
    end
  end
end