defmodule Mesh.ChannelTest do
  use ExUnit.Case
  doctest Mesh.Channel

  alias Mesh.Channel

  test "item returned by start_link is a channel" do
    ch = Channel.start_link()

    assert Channel.is_channel(ch) == true
  end

  test "suspicious things are not channels" do
    assert Channel.is_channel(42) == false
    assert Channel.is_channel({Mesh.Channel, 42}) == false
  end
end