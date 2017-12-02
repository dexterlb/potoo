defmodule Ui.TcpServer.Handler do
  def init(_opts) do
    {:ok, nil}
  end

  def socket_handle({:text, data}, state) do
    {:reply, ["hi, ", data], state}
  end
end