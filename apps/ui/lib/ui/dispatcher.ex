defmodule Ui.Dispatcher do
  def dispatch do
    [
      {:_, [
        {"/ws", Ui.StreamServer.WebSocketListener, []},
        {:_, Plug.Adapters.Cowboy.Handler, {Ui.Router, []}}
      ]}
    ]
  end
end