defmodule Server.StreamServer.TcpServer do
  require Logger

  def start_link([port: port]) do
    val = :ranch.start_listener(
      make_ref(),
      100,
      :ranch_tcp,
      [port: port, connection_type: :worker],
      Server.StreamServer.TcpListener,
      []
    )
    Logger.debug("start tcp server: #{inspect(val)}")
    val
  end
end