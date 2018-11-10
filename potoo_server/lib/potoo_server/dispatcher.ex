defmodule PotooServer.Dispatcher do
  def dispatch do
    [
      {:_, [
        {"/ws", PotooServer.StreamServer.WebSocketListener, []},
        {:_, Plug.Cowboy.Handler, {PotooServer.Router, []}}
      ]}
    ]
  end
end
