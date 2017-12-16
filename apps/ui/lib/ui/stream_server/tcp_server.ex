defmodule Ui.StreamServer.TcpServer do
  require Logger

  def start_link(opts \\ []) do
    val = :ranch.start_listener(
      make_ref(), 
      100, 
      :ranch_tcp, 
      opts, 
      Ui.StreamServer.TcpListener,
      [packet: :line]
    )
    Logger.debug("start tcp server: #{inspect(val)}")
    val
  end
end