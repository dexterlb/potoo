defmodule Ui.Dispatcher do
  def dispatch do
    [
      {:_, [
        {"/ws", Ui.SocketHandler, []},
        {:_, Plug.Adapters.Cowboy.Handler, {Ui.Router, []}}
      ]}
    ]
  end
end