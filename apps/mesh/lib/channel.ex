defmodule Mesh.Channel do
  defmacro is_channel(value) do
    quote do
      (
        is_tuple(unquote(value)) and
        tuple_size(unquote(value)) == 2 and
        elem(unquote(value), 0) == Mesh.Channel and
        is_pid(elem(unquote(value), 1))
      )
    end
  end

  def start_link do
    {__MODULE__, spawn_link(fn() -> useless() end)}
  end

  defp useless do
    receive do
      _ -> useless()
    end
  end
end