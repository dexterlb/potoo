defmodule Contract.Type do
  def is_valid(nil), do: true
  def is_valid(:bool), do: true
  def is_valid(:atom), do: true
  def is_valid(:integer), do: true
  def is_valid(:float), do: true
  def is_valid(:string), do: true
  def is_valid(:delegate), do: true
  def is_valid({:literal, _}), do: true
  def is_valid({:type, t, %{}}), do: is_valid(t)
  def is_valid({:union, t1, t2}), do: is_valid(t1) && is_valid(t2)
  def is_valid({:list, t}), do: is_valid(t)
  def is_valid({:map, t1, t2}), do: is_valid(t1) && is_valid(t2)
  def is_valid({:struct, fields = %{}}) do
    fields |> Map.to_list |> Enum.all?(&is_valid_struct_field/1)
  end
  def is_valid({:struct, fields = [_|_]}) do
    fields |> Enum.all?(&is_valid/1)
  end
  def is_valid({:struct, fields}) when is_tuple(fields) do
    is_valid({:struct, Tuple.to_list(fields)})
  end
  def is_valid(_), do: false

  def is_of(nil, nil), do: true
  def is_of(:atom, x) when is_atom(x), do: true
  def is_of(:bool, x) when is_boolean(x), do: true
  def is_of(:integer, x) when is_integer(x), do: true
  def is_of(:float, x) when is_float(x), do: true
  def is_of(:string, x) when is_bitstring(x), do: true
  def is_of(:delegate, %Mesh.Contract.Delegate{}), do: true
  def is_of({:literal, x}, y), do: x == y
  def is_of({:type, t, %{}}, x), do: is_of(t, x)
  def is_of({:union, t1, t2}, x) do
    is_of(t1, x) || is_of(t2, x)
  end
  def is_of({:list, _}, []), do: true
  def is_of({:list, t}, [head | tail]) do
    is_of(t, head) && is_of({:list, t}, tail)
  end
  def is_of({:map, t1, t2}, map = %{}) do
    {keys, values} = map |> Map.to_list |> Enum.unzip

    is_of({:list, t1}, keys) && is_of({:list, t2}, values)
  end
  def is_of({:struct, fields = %{}}, struct = %{}) do
    fields 
      |> Map.to_list 
      |> Enum.map(
        fn({key, type}) ->
          {key, type, Map.get(struct, key)}
        end)
      |> Enum.all?(&is_of_struct_field/1)
  end
  def is_of({:struct, fields = [_|_]}, struct = [_|_]) do
    Enum.zip(fields, struct) |> Enum.all?(&is_of_struct_field/1)
  end
  def is_of({:struct, fields}, struct) when (is_tuple(fields) and is_tuple(struct)) do
    is_of({:struct, Tuple.to_list(fields)}, Tuple.to_list(struct))
  end
  def is_of(t, v) do
    case is_valid(t) do
      true  -> false
      _     -> raise "Trying to test if value #{inspect(v)} is of an invalid type #{inspect(t)}"
    end
  end

  def to_s(t) do
    case is_valid(t) do
      true -> Kernel.inspect(t)
      _    -> "<invalid type>"
    end
  end

  def cast(t, x), do: nil

  defp is_valid_struct_field({key, value_type}) do
    (is_atom(key) || is_of(:string, key))
    && is_valid(value_type)
  end

  defp is_of_struct_field({key, value_type, value}) do
    (is_atom(key) || is_of(:string, key))
    && is_of(value_type, value)   
  end

  defp is_of_struct_field({value_type, value}) do
    is_of(value_type, value)   
  end
end