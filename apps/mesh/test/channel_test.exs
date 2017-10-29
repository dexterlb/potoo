defmodule Mesh.ChannelTest do
  use ExUnit.Case
  doctest Mesh.Channel

  alias Mesh.Channel

  test "item returned by start_link is a channel" do
    {:ok, ch} = Channel.start_link()

    assert Channel.is_channel(ch) == true
  end

  test "suspicious things are not channels" do
    assert Channel.is_channel((fn() -> 42 end).()) == false
    assert Channel.is_channel({Mesh.Channel, 42}) == false
  end

  test "can use channel to send a message to one recipient" do
    {:ok, ch} = Channel.start_link()

    :ok = Channel.subscribe(ch, self(), :foo)

    spawn(fn() -> Channel.send(ch, 42) end)

    assert_receive({:foo, 42})
  end

  test "can unsubscribe from channel" do
    {:ok, ch} = Channel.start_link()

    :ok = Channel.subscribe(ch, self(), :foo)

    Channel.unsubscribe(ch, self())

    :timer.sleep(100)

    spawn(fn() -> Channel.send(ch, 42) end)

    refute_receive({:foo, 42})
  end
end