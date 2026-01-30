defmodule Jennie.Tokeniser do
  def tokenise(bin, line, column, opts) when is_binary(bin) do
    tokenise(String.to_charlist(bin), line, column, opts)
  end

  def tokenise(list, line, column, opts)
      when is_list(list) and is_integer(line) and line >= 0 and is_integer(column) and column >= 0 do
    tokenise(list, line, column, opts, [{line, column}], [])
  end

  defp tokenise(~c"{{" ++ t, line, column, opts, buffer, acc) do
    {marker, t} = retrieve_marker(t)

    case expr(t, line, column + 2 + length(marker), opts, []) do
      {:error, _, _, _} = error ->
        error

      {:ok, expr, new_line, new_column, rest} ->
        acc = tokenise_text(buffer, acc)
        final = {:tag, line, column, marker, token_key(expr, [], [])}
        tokenise(rest, new_line, new_column, opts, [{new_line, new_column}], [final | acc])
    end
  end

  defp tokenise(~c"\r\n" ++ t, line, _column, opts, buffer, acc) do
    new_line = {:new_line, line + 1, 0}
    acc = tokenise_text(buffer, acc)
    tokenise(t, line + 1, opts.indentation + 1, opts, [{line + 1, 0}], [new_line | acc])
  end

  defp tokenise(~c"\n" ++ t, line, _column, opts, buffer, acc) do
    new_line = {:new_line, line + 1, 0}
    acc = tokenise_text(buffer, acc)
    tokenise(t, line + 1, opts.indentation + 1, opts, [{line + 1, 0}], [new_line | acc])
  end

  defp tokenise([h | t], line, column, opts, buffer, acc) do
    tokenise(t, line, column + 1, opts, [h | buffer], acc)
  end

  defp tokenise([], line, column, _opts, buffer, acc) do
    eof = {:eof, line, column}
    tokens = Enum.reverse([eof | tokenise_text(buffer, acc)])
    {:ok, trim(tokens)}
  end

  # Tokenise an expression until }} is found
  defp expr([?}, ?} | t], line, column, _opts, buffer) do
    {:ok, Enum.reverse(buffer), line, column + 2, t}
  end

  defp expr(~c"\n" ++ t, line, _column, opts, buffer) do
    expr(t, line + 1, opts.indentation + 1, opts, [?\n | buffer])
  end

  defp expr(~c" " ++ t, line, column, opts, buffer) do
    expr(t, line, column + 1, opts, buffer)
  end

  defp expr([h | t], line, column, opts, buffer) do
    expr(t, line, column + 1, opts, [h | buffer])
  end

  defp expr([], line, column, _opts, _buffer) do
    {:error, line, column, "missing token '}}'"}
  end

  # Parses the internal expression of a tag
  defp token_key(~c".", _, _), do: ["."]

  defp token_key(~c"." ++ rest, current, acc) do
    token = current |> Enum.reverse() |> IO.chardata_to_string()
    token_key(rest, [], [token | acc])
  end

  defp token_key(~c"", current, acc) do
    token = current |> Enum.reverse() |> IO.chardata_to_string()
    Enum.reverse([token | acc])
  end

  defp token_key([h | t], current, acc) do
    token_key(t, [h | current], acc)
  end

  # Retrieve marker for {{

  defp retrieve_marker([marker | t]) when marker in [?#, ?/, ?^] do
    {[marker], t}
  end

  defp retrieve_marker(t) do
    {~c"", t}
  end

  # Tokenise the buffered text by appending
  # it to the given accumulator.

  defp tokenise_text([{_line, _column}], acc) do
    acc
  end

  defp tokenise_text(buffer, acc) do
    [{line, column} | buffer] = Enum.reverse(buffer)
    tag = if Enum.all?(buffer, &(&1 == ?\s)), do: :whitespace, else: :text
    [{tag, line, column, buffer} | acc]
  end

  defp trim(tokens) do
    {_, _, tokens} =
      Enum.reduce(tokens, {nil, nil, []}, fn current, {prev, prev2, acc} ->
        case {prev2, prev, current} do
          {{:new_line, _, _}, {:tag, _, _, ~c"#", _}, {:new_line, _, _}} ->
            {current, prev, [current | List.delete_at(acc, 1)]}

          {{:whitespace, _, _, _}, {:tag, _, _, ~c"#", _}, {:new_line, _, _}} ->
            {current, prev, List.delete_at(acc, 1)}

          {{:new_line, _, _}, {:tag, _, _, ~c"/", _}, {:new_line, _, _}} ->
            {prev, prev2, acc}

          {{:new_line, _, _}, {:whitespace, _, _, _}, {:tag, _, _, ~c"/", _}} ->
            {current, prev, [current | Enum.drop(acc, 2)]}

          {_, _, _} ->
            {current, prev, [current | acc]}
        end
      end)

    Enum.reverse(tokens)
  end
end
