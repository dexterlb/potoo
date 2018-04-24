defmodule Ui.StreamServer.WebSocketListener do
  alias Ui.StreamServer.Handler
  require Logger

  @behaviour :cowboy_websocket_handler

  def init(_, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  @timeout 10000 # terminate if no activity for one minute

  #Called on websocket connection initialization.
  def websocket_init(_type, req, opts) do
    Logger.debug(fn -> ["new ws client: ", inspect(req)] end)

    {:ok, handler_state} = Handler.init(opts)

    {:ok, req, handler_state, @timeout}
  end

  def websocket_handle({:text, data} = msg, req, state) do
    Logger.debug(fn -> ["ws -> ", data] end)

    Handler.socket_handle(msg, state) |> handler_reply(req, state)
  end

  def websocket_handle(_other, req, state) do
    {:ok, req, state}
  end

  def websocket_info(info, req, state) do
    Handler.socket_info(info, state) |> handler_reply(req, state)
  end


  defp handler_reply(reply, req, _) do
    case reply do
      {:reply, reply, new_state} ->
        Logger.debug(fn -> ["ws <- ", reply] end)
        {:reply, {:text, reply}, req, new_state}
      {:noreply, new_state} ->
        {:noreply, req, new_state}
    end
  end

  def websocket_terminate(_reason, req, _state) do
    Logger.debug(fn -> ["ws conn died: ", inspect(req)] end)
    :ok
  end
end