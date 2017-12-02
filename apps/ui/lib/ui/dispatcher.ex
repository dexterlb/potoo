defmodule Ui.Dispatcher do
  def dispatch do
    [
      {:_, [
        {"/ws", Ui.WebSocketHandler, []},
        {:_, Plug.Adapters.Cowboy.Handler, {Ui.Router, []}}
      ]}
    ]
  end
end