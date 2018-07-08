defmodule Ui.Dispatcher do
  def dispatch do
    [
      {:_, [
        {"/ws", Ui.StreamServer.WebSocketListener, []},
        {:_, Plug.Adapters.Cowboy2.Handler, {Ui.Router, []}}
      ]}
    ]
  end
end