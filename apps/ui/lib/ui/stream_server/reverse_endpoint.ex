defmodule Ui.StreamServer.ReverseEndpoint do
  use GenServer
  require OK
  
  def init(parent) do
    Process.link(parent)
    Process.flag(:trap_exit, true)
    OK.for do
      chan <- Mesh.Channel.start_link()
    after
      {parent, nil, chan}
    end
  end

  def handle_call(call, from = {sender, _}, state = {parent, _, _}) do
    case sender == parent do
      false -> handle_regular_call(call, from, state)
      true  -> handle_parent_call(call, from, state)
    end
  end

  def handle_parent_call({:set_contract, new_contract}, _from, {parent, _, chan}) do
    Mesh.Channel.send(chan, new_contract)
    {:reply, :ok, {parent, new_contract, chan}}
  end

  def handle_parent_call(_call, _from, _state) do
    raise "did you try calling yourself?"
  end

  def handle_regular_call(:contract, _from, state = {_, contract, _}) do
    {:reply, contract, state}
  end

  def handle_regular_call(:subscribe_contract, _from, state = {_, _, chan}) do
    {:reply, chan, state}
  end

  def handle_regular_call(call, from, state = {parent, _, _}) do
    send(parent, {:incoming_call, from, call})
    {:noreply, state}
  end

  def handle_info({:EXIT, _, _}, _) do
    {:stop, :link_exited}
  end

  def start_link(parent) do
    GenServer.start_link(
      __MODULE__,
      parent
    )
  end
end
