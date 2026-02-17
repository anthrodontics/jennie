defmodule Jennie.Utils do
  def to_map(data)
  
  # Convert structs to maps, then continue recursion
  def to_map(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> to_map()
  end
  
  def to_map(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      k = if is_atom(k), do: Atom.to_string(k), else: k
      {k, to_map(v)} end)
    |> Enum.into(%{})
  end
  
  def to_map(list) when is_list(list) do
    Enum.map(list, &to_map/1)
  end
  
  def to_map(other), do: other
end