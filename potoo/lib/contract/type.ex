defmodule Potoo.Contract.Type do
  @moduledoc """
  This module implements a basic type system. Values can be tested for type
  affinity and can be cast to applicable types.
  """
  require Potoo.Channel

  alias Potoo.Contract

  @type t :: primitive | composite
  @type primitive :: nil | :bool | :atom | :integer | :float | :string | :delegate
  @type composite :: {:type, t, Contract.data} |
                     {:union, t, t} |
                     {:list, t} |
                     {:map, t, t} |
                     {:struct, %{required(Contract.key) => t}} |
                     {:struct, [t]} |
                     {:channel, t}

  @doc """
  Test if a term is a valid type
  """
  @spec is_valid(t) :: boolean
  def is_valid(t)
  def is_valid(nil), do: true
  def is_valid(:bool), do: true
  def is_valid(:atom), do: true
  def is_valid(:integer), do: true
  def is_valid(:float), do: true
  def is_valid(:string), do: true
  def is_valid(:delegate), do: true
  def is_valid({:channel, t}), do: is_valid(t)
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

  @doc """
  Test if a value has (can be said to have) the given type
  """
  @spec is_of(t, term) :: boolean
  def is_of(nil, nil), do: true
  def is_of(:atom, x) when is_atom(x), do: true
  def is_of(:bool, x) when is_boolean(x), do: true
  def is_of(:integer, x) when is_integer(x), do: true
  def is_of(:float, x) when is_float(x), do: true
  def is_of(:string, x) when is_bitstring(x), do: true
  def is_of(:delegate, %Potoo.Contract.Delegate{}), do: true
  def is_of({:channel, t}, x) when Potoo.Channel.is_channel(x) do
    is_valid(t)  # todo: typed channels
  end
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

  @doc """
  Visual representation of the given type
  """
  @spec to_s(t) :: String.t
  def to_s(t) do
    case is_valid(t) do
      true -> Kernel.inspect(t)
      _    -> "<invalid type>"
    end
  end

  @doc """
  Try to cast a term to the given type. Works with most nested structures too!
  """
  @spec cast(term, t) :: {:ok, term} | {:error, String.t}
  def cast(x, t) do
    case is_of(t, x) do
      true  -> {:ok, x}
      false -> do_cast(x, t)
    end
  end


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

  defp do_cast(x, :atom) when is_bitstring(x) do
    try do
      {:ok, String.to_existing_atom(x)}
    rescue
      err -> {:error, err}
    end
  end
  defp do_cast("false", :bool), do: {:ok, false}
  defp do_cast("False", :bool), do: {:ok, false}
  defp do_cast("FALSE", :bool), do: {:ok, false}
  defp do_cast("f", :bool), do: {:ok, false}
  defp do_cast("F", :bool), do: {:ok, false}
  defp do_cast("#f", :bool), do: {:ok, false}
  defp do_cast("no", :bool), do: {:ok, false}
  defp do_cast("0", :bool), do: {:ok, false}
  defp do_cast(:false, :bool), do: {:ok, false}
  defp do_cast("true", :bool), do: {:ok, true}
  defp do_cast("True", :bool), do: {:ok, true}
  defp do_cast("TRUE", :bool), do: {:ok, true}
  defp do_cast("t", :bool), do: {:ok, true}
  defp do_cast("T", :bool), do: {:ok, true}
  defp do_cast("#t", :bool), do: {:ok, true}
  defp do_cast("yes", :bool), do: {:ok, true}
  defp do_cast("1", :bool), do: {:ok, true}
  defp do_cast(:true, :bool), do: {:ok, true}
  defp do_cast(x, :bool) when is_integer(x), do: x != 0

  defp do_cast(s, :integer) when is_bitstring(s) do
    case Integer.parse(s) do
      :error -> {:error, "unable to cast #{inspect(s)} to integer"}
      {n, _} when is_integer(n) -> {:ok, n}
    end
  end
  defp do_cast(f, :integer) when is_float(f) do
    {:ok, round(f)}
  end

  defp do_cast(s, :float) when is_bitstring(s) do
    case Float.parse(s) do
      :error -> {:error, "unable to cast #{inspect(s)} to float"}
      {n, _} when is_float(n) -> {:ok, n}
    end
  end
  defp do_cast(i, :float) when is_integer(i) do
    {:ok, i / 1}
  end

  defp do_cast(true, :string), do: "true"
  defp do_cast(false, :string), do: "false"
  defp do_cast(a, :string) when is_atom(a) do
    {:ok, Atom.to_string(a)}
  end
  defp do_cast(i, :string) when is_integer(i) do
    {:ok, Integer.to_string(i)}
  end
  defp do_cast(f, :string) when is_float(f) do
    {:ok, Float.to_string(f)}
  end

  defp do_cast(x, {:type, t, _}) do
    cast(x, t)
  end

  defp do_cast(x, t = {:union, t1, t2}) do
    case cast(x, t1) do
      {:ok, v} -> {:ok, v}
      {:error, e1} -> case do_cast(x, t2) do
        {:ok, v} -> {:ok, v}
        {:error, e2} ->
          {:error, [
              "Unable to cast #{inspect(x)} to #{inspect(t)} ",
              e1, e2
            ]
          }
      end
    end
  end

  defp do_cast(tu, t = {:list, _}) when is_tuple(tu) do
    do_cast(Tuple.to_list(tu), t)
  end
  defp do_cast(l, t = {:list, t1}) when is_list(l) do
    l |> Enum.map(fn(x) -> cast(x, t1) end) |> check_list_results(
      "cannot cast #{inspect(l)} to #{inspect(t)}"
    )
  end

  defp do_cast(m = %{}, {:map, t1, t2} = t) do
    case m |> Map.to_list |> do_cast({:list, {:struct, {t1, t2}}}) do
      {:ok, pairs} -> {:ok, Map.new(pairs)}
      {:error, err} -> {:error, [
        "cannot cast #{inspect(m)} to #{inspect(t)}"
        | err
      ]}
    end
  end

  defp do_cast(m = %{}, {:struct, fields = %{}} = struct) do
    {keys, results} = fields
      |> Map.to_list
      |> Enum.map(
        fn({key, type}) -> {key, cast(Map.get(m, key), type)} end)
      |> Enum.unzip

    case check_list_results(results, "cannot cast #{inspect(m)} to #{inspect(struct)}") do
      {:error, _} = err -> err
      {:ok, values} -> {:ok, Enum.zip(keys, values) |> Map.new}
    end
  end
  defp do_cast(l, {:struct, fields} = struct) when is_list(fields) and is_list(l) do
    results = Enum.zip(fields, l) |> Enum.map(
      fn({type, x}) -> cast(x, type) end)

    case check_list_results(results, "cannot cast #{inspect(l)} to #{inspect(struct)}") do
      {:error, _} = err -> err
      {:ok, _} = values -> values
    end
  end
  defp do_cast(tu, {:struct, _} = struct) when is_tuple(tu) do
    do_cast(Tuple.to_list(tu), struct)
  end
  defp do_cast(l, {:struct, fields}) when is_list(l) and is_tuple(fields) do
    case do_cast(l, {:struct, Tuple.to_list(fields)}) do
      {:ok, values} -> {:ok, List.to_tuple(values)}
      {:error, _} = err -> err
    end
  end

  defp do_cast(x, t), do: {:error, "cannot cast #{inspect(x)} to #{inspect(t)}"}


  defp check_list_results(results, error_message) do
    case results |> Enum.filter(&is_fail/1) do
      [] -> compose_results(results)
      fails -> compose_fails(fails, error_message)
    end
  end

  defp is_fail({:error, _}), do: true
  defp is_fail({:ok, _}), do: false

  defp compose_fails(fails, message) do
    {:error, [message | extract_fails(fails)]}
  end

  defp compose_results(results) do
    {:ok, extract_oks(results)}
  end

  defp extract_fails(fails) do
    fails |> Enum.map(fn({:error, err}) -> err end)
  end

  defp extract_oks(results) do
    results |> Enum.map(fn({:ok, result}) -> result end)
  end
end