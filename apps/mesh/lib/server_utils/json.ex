defmodule Mesh.ServerUtils.Json do
  alias Mesh.ServerUtils.PidCache
  require OK
  import OK, only: ["~>>": 2]

  def jsonify(%Mesh.Contract.Function{name: name, argument: argument, retval: retval, data: data}, pc) do
    %{
      "__type__" => "function",
      "name" => name,
      "argument" => jsonify(argument, pc),
      "retval" => jsonify(retval, pc),
      "data" => data
    }
  end
  def jsonify(nil, _), do: nil
  def jsonify(b, _) when is_boolean(b), do: b
  def jsonify(%Mesh.Contract.Delegate{destination: destination, data: data}, pc) do
    %{
      "__type__" => "delegate",
      "destination" => PidCache.get(pc, {:delegate, destination}),
      "data" => data
    }
  end
  def jsonify({Mesh.Channel, chan_pid}, pc) do
    %{
      "__type__" => "channel",
      "id" => PidCache.get(pc, {:channel, chan_pid})
    }
  end
  def jsonify(contract = %{}, pc) do
    # todo: fix the case when there's a __key__ in the map
    contract |> Enum.map(fn({k, v}) -> {jsonify(k, pc), jsonify(v, pc)} end) |> Map.new
  end
  def jsonify(t, pc) when is_tuple(t) do
    t |> Tuple.to_list |> jsonify(pc)
  end
  def jsonify(l, pc) when is_list(l) do
    l |> Enum.map(fn(x) -> jsonify(x, pc) end)
  end
  def jsonify(a, _) when is_atom(a) do
    Atom.to_string(a)
  end
  def jsonify(x, _), do: x

  def unjsonify!(j, pc) do
    {:ok, x} = unjsonify(j, pc)
    x
  end
  def unjsonify(
    %{
      "__type__" => "channel",
      "id" => id
    },
    pc) do

    case PidCache.get(pc, {:channel, id}) do
      nil -> {:error, "no such channel pid"}
      pid -> {:ok, {Mesh.Channel, pid}}
    end
  end
  def unjsonify(
      %{
        "__type__" => "function",
        "name" => name,
        "argument" => argument,
        "retval" => retval,
        "data" => data
      },
      pc
    ) do
  
    OK.for do
      actual_argument <- unjsonify_type(argument, pc)
      actual_retval   <- unjsonify_type(retval, pc)
      actual_data     <- unjsonify(data, pc)
    after
      %Mesh.Contract.Function{
        name: name,
        argument: actual_argument,
        retval: actual_retval,
        data: actual_data
      }
    end
  end
  def unjsonify(
      %{
        "__type__" => "delegate",
        "destination" => destination,
        "data" => data
      },
      pc
    ) do
        
    OK.for do
      actual_data     <- unjsonify(data, pc)
      actual_destination <- PidCache.fetch(pc, {:delegate, destination})
    after
      %Mesh.Contract.Delegate{
        destination: actual_destination,
        data: actual_data
      }
    end
  end


  def unjsonify(x, _), do: {:ok, x}

  def unjsonify_type!(j, pc) do
    {:ok, t} = unjsonify_type(j, pc)
    t
  end

  def unjsonify_type(nil, _),        do:  {:ok, nil}
  def unjsonify_type("bool", _),     do: {:ok, :bool}
  def unjsonify_type("atom", _),     do: {:ok, :atom}
  def unjsonify_type("string", _),   do: {:ok, :string}
  def unjsonify_type("integer", _),  do: {:ok, :integer}
  def unjsonify_type("float", _),    do: {:ok, :float}
  def unjsonify_type("delegate", _), do: {:ok, :delegate}
  def unjsonify_type(["channel", j], pc) do
    OK.for do
      t <- unjsonify_type(j, pc)
    after
      {:channel, t}
    end
  end
  def unjsonify_type(["literal", value], _) do
    {:ok, {:literal, value}}
  end
  def unjsonify_type(["type", j], pc) do
    OK.for do
      t <- unjsonify_type(j, pc)
    after
      {:type, t}
    end
  end
  def unjsonify_type(["list", j], pc) do
    OK.for do
      t <- unjsonify_type(j, pc)
    after
      {:list, t}
    end
  end
  def unjsonify_type(["union", j1, j2], pc) do
    OK.for do
      t1 <- unjsonify_type(j1, pc)
      t2 <- unjsonify_type(j2, pc)
    after
      {:union, t1, t2}
    end
  end
  def unjsonify_type(["map", j1, j2], pc) do
    OK.for do
      t1 <- unjsonify_type(j1, pc)
      t2 <- unjsonify_type(j2, pc)
    after
      {:map, t1, t2}
    end
  end
  def unjsonify_type(["struct", fields = %{}], pc) do
    fields
      |> Enum.map(fn({name, j}) ->
          OK.for do
            t <- unjsonify_type(j, pc)
          after
            {name, t}
          end
        end)
      |> squeeze_errors
      ~>> make_map_struct  # todo: maybe implement an 'fmap' operator in the OK library
  end
  def unjsonify_type(["struct", fields], pc) when is_list(fields) do
    fields
      |> Enum.map(fn(j) ->
          OK.for do
            t <- unjsonify_type(j, pc)
          after
            t
          end
        end)
      |> squeeze_errors
      ~>> make_tuple_struct  # todo: maybe implement an 'fmap' operator in the OK library
  end

  defp squeeze_errors(l) do
    case l |> Enum.filter(&is_error/1) do
      [] -> {:ok, Enum.map(l, fn({:ok, x}) -> x end)}
      errors -> {:error, "errors while decoding items: #{inspect(errors)}"}
    end
  end

  defp is_error({:ok, _}), do: false
  defp is_error({:error, _}), do: true

  defp make_map_struct(l), do: {:ok, {:struct, Map.new(l)}}
  defp make_tuple_struct(l), do: {:ok, {:struct, List.to_tuple(l)}}
end