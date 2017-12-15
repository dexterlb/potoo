defmodule Ui.StreamServer.ReverseEndpoint do
  use GenServer
  
  def init(parent) do
    {:ok, {parent, nil}}
  end

  def handle_call(call, from = {sender, _}, state = {parent, _}) do
    case sender == parent do
      false -> handle_regular_call(call, from, state)
      true  -> handle_parent_call(call, from, state)
    end
  end

  def handle_parent_call({:set_contract, new_contract}, _from, state = {parent, contract}) do
    {:reply, :ok, {parent, new_contract}}
  end

  def handle_parent_call(call, from, state) do
    raise "did you try calling yourself?"
  end

  def handle_regular_call(call, from, state = {parent, _contract}) do
    send(parent, {:incoming_call, from, call})
    {:noreply, state}
  end

  def start_link(parent) do
    GenServer.start_link(
      __MODULE__,
      parent
    )
  end
end
