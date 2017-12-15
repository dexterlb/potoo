defmodule Ui.StreamServer.ReverseEndpoint do
  use GenServer
  
  def handle_call(call, from, parent) do
    send(parent, {:incoming_call, from, call})
    {:noreply, parent}
  end

  def start_link(parent) do
    GenServer.start_link(
      __MODULE__,
      parent
    )
  end
end
