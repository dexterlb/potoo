defmodule Server.Dispatcher do
  def dispatch do
    [
      {:_, [
        {"/ws", Server.StreamServer.WebSocketListener, []},
        {:_, Plug.Adapters.Cowboy2.Handler, {Server.Router, []}}
      ]}
    ]
  end
end