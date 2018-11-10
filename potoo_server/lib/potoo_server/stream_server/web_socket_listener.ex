defmodule PotooServer.StreamServer.WebSocketListener do
  alias PotooServer.StreamServer.Handler
  require Logger

  @behaviour :cowboy_websocket

  def init(req, opts) do
    Logger.debug(fn -> ["new ws client: ", inspect(req)] end)
    {:cowboy_websocket, req, opts}
  end

  #Called on websocket connection initialization.
  def websocket_init(opts) do
    Handler.init(opts)
  end

  def websocket_handle({:text, data} = msg, state) do
    Logger.debug(fn -> ["ws -> ", data] end)

    Handler.socket_handle(msg, state) |> handler_reply(state)
  end

  def websocket_handle(_other, state) do
    {:ok, state}
  end

  def websocket_info(info, state) do
    Handler.socket_info(info, state) |> handler_reply(state)
  end


  defp handler_reply(reply, _) do
    case reply do
      {:reply, reply, new_state} ->
        Logger.debug(fn -> ["ws <- ", reply] end)
        {:reply, {:text, reply}, new_state}
      {:noreply, new_state} ->
        {:noreply, new_state}
    end
  end

  def websocket_terminate(_reason, req, _state) do
    Logger.debug(fn -> ["ws conn died: ", inspect(req)] end)
    :ok
  end
end