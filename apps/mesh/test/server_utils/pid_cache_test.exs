defmodule PidCacheTest do
  use ExUnit.Case
  doctest Mesh.ServerUtils.PidCache

  alias Mesh.ServerUtils.PidCache

  test "can put and retreive a pid" do
    {:ok, pc} = PidCache.start_link()

    proc = spawn_link(fn() -> nil end)

    id = PidCache.get(pc, {:my_pids, proc})

    proc2 = PidCache.get(pc, {:my_pids, id})

    assert is_pid(proc2)
    assert proc == proc2
    assert is_integer(id)
  end

  test "getting non-existant id yields nil" do
    {:ok, pc} = PidCache.start_link()

    assert PidCache.get(pc, {:my_pids, 42}) == nil
  end

  test "putting the same pid twice yields the same id" do
    {:ok, pc} = PidCache.start_link()

    proc = spawn_link(fn() -> nil end)

    id1 = PidCache.get(pc, {:my_pids, proc})

    id2 = PidCache.get(pc, {:my_pids, proc})

    assert id1 == id2
  end
end