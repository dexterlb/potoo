defmodule Server.Dispatcher do
  def dispatch do
    [
      {:_, [
        {"/ws", Server.StreamServer.WebSocketListener, []},
        {:_, Plug.Cowboy.Handler, {Server.Router, []}}
      ]}
    ]
  end
end
