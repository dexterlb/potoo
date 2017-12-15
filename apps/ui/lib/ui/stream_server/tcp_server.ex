defmodule Ui.StreamServer.TcpServer do
  def start_link(opts \\ []) do
    {:ok, _} = :ranch.start_listener(
      make_ref(), 
      100, 
      :ranch_tcp, 
      opts, 
      Ui.StreamServer.TcpListener,
      [packet: :line]
    )
  end
end