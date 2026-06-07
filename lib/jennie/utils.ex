defmodule Jennie.Utils do
  @moduledoc false

  @doc """
  Normalise a single value into a renderer-friendly frame.

  * structs become string-keyed maps
  * maps have their top-level keys stringified
  * keyword lists become string-keyed maps
  * everything else is returned untouched

  Nested values are intentionally left alone; they are normalised lazily when
  (and if) they are themselves pushed onto the context stack.
  """
  @spec normalise(term()) :: term()
  def normalise(%_{} = struct) do
    struct |> Map.from_struct() |> normalise()
  end

  def normalise(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {stringify_key(k), v} end)
  end

  def normalise([{key, _} | _] = list) when is_atom(key) do
    if Keyword.keyword?(list) do
      Map.new(list, fn {k, v} -> {stringify_key(k), v} end)
    else
      list
    end
  end

  def normalise(other), do: other

  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key) when is_binary(key), do: key
  defp stringify_key(key), do: to_string(key)
end
