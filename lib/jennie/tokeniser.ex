defmodule Jennie.Tokeniser do
  @moduledoc """
  Turns a template string into a flat list of tokens.

  Tokens are one of:

    * `{:text, binary, line, col}`
    * `{:tag, type, payload, line, col}`

  where `type` is one of `:var`, `:unescaped`, `:section`, `:inverted`,
  `:close`, `:comment`, `:partial`, `:delimiter`. The payload is:

    * `{:var | :unescaped, keys}` — `keys` is the dotted name split on `"."`
    * `{:section | :inverted | :close, keys}`
    * `{:partial, name}` — the raw (unsplit) partial name
    * `{:comment, _}` / `{:delimiter, _}` — content is irrelevant to output

  Set-delimiter tags (`{{=<% %>=}}`) are applied during scanning so subsequent
  tags use the new delimiters.
  """

  alias Jennie.SyntaxError

  @standalone_types [:section, :inverted, :close, :comment, :partial, :delimiter]

  @doc """
  Tokenise `source`, returning `{:ok, tokens}` or raising `Jennie.SyntaxError`.
  """
  @spec tokenise(String.t()) :: {:ok, [tuple()]}
  def tokenise(source) when is_binary(source) do
    tokens = scan(source, "{{", "}}", 1, 1, [], [])
    {:ok, standalone(tokens)}
  end

  # `buffer` accumulates raw text characters (as an iolist, reversed);
  # `acc` accumulates completed tokens (reversed).
  defp scan("", _otag, _ctag, line, col, buffer, acc) do
    buffer |> flush_text(line, col, acc) |> Enum.reverse()
  end

  defp scan(source, otag, ctag, line, col, buffer, acc) do
    case chunk_before(source, otag) do
      :none ->
        # No more tags; the rest is literal text.
        scan("", otag, ctag, line, col, [source | buffer], acc)

      {text, after_otag} ->
        {line2, col2} = advance(text, line, col)
        acc = flush_text([text | buffer], line, col, acc)
        read_tag(after_otag, otag, ctag, line2, col2, acc)
    end
  end

  # Splits `source` at the first occurrence of `otag`, returning the leading
  # text and the remainder after `otag`. `:none` if `otag` is absent.
  defp chunk_before(source, otag) do
    case :binary.match(source, otag) do
      :nomatch ->
        :none

      {pos, len} ->
        {binary_part(source, 0, pos), binary_slice(source, pos + len, byte_size(source))}
    end
  end

  # `rest` is positioned just after the opening delimiter.
  defp read_tag(rest, otag, ctag, line, col, acc) do
    # The column of the opening delimiter (for error reporting / tokens).
    open_col = col

    {type, sigil_len} = sigil(rest, otag)
    inner_start = binary_slice(rest, sigil_len, byte_size(rest))
    closing = closing_delim(type, otag, ctag)

    case :binary.match(inner_start, closing) do
      :nomatch ->
        raise SyntaxError,
          message: "unclosed tag, expected #{inspect(closing)}",
          line: line,
          column: open_col

      {pos, len} ->
        raw = binary_part(inner_start, 0, pos)
        after_close = binary_slice(inner_start, pos + len, byte_size(inner_start))
        # Advance position past the opening delimiter, sigil, content, and close.
        consumed = binary_part(rest, 0, sigil_len + pos + len)
        {line2, col2} = advance(consumed, line, col)
        {line2, col2} = {line2, col2 + byte_size(otag)}

        case build_token(type, raw, line, open_col) do
          {:set_delimiters, new_otag, new_ctag} ->
            token = {:tag, :delimiter, {:delimiter, raw}, line, open_col}
            scan(after_close, new_otag, new_ctag, line2, col2, [], [token | acc])

          token ->
            scan(after_close, otag, ctag, line2, col2, [], [token | acc])
        end
    end
  end

  # Determine the tag type and the length of its sigil.
  defp sigil(rest, "{{") do
    case rest do
      "{" <> _ -> {:unescaped_triple, 1}
      "&" <> _ -> {:unescaped, 1}
      "#" <> _ -> {:section, 1}
      "^" <> _ -> {:inverted, 1}
      "/" <> _ -> {:close, 1}
      "!" <> _ -> {:comment, 1}
      ">" <> _ -> {:partial, 1}
      "=" <> _ -> {:delimiter, 1}
      _ -> {:var, 0}
    end
  end

  defp sigil(rest, _otag) do
    # With custom delimiters the triple-mustache form is unavailable; `&`
    # remains the way to request unescaped output.
    case rest do
      "&" <> _ -> {:unescaped, 1}
      "#" <> _ -> {:section, 1}
      "^" <> _ -> {:inverted, 1}
      "/" <> _ -> {:close, 1}
      "!" <> _ -> {:comment, 1}
      ">" <> _ -> {:partial, 1}
      "=" <> _ -> {:delimiter, 1}
      _ -> {:var, 0}
    end
  end

  # The triple mustache closes with `}}}`; the delimiter tag closes with `=` +
  # ctag; everything else closes with the current ctag.
  defp closing_delim(:unescaped_triple, _otag, _ctag), do: "}}}"
  defp closing_delim(:delimiter, _otag, ctag), do: "=" <> ctag
  defp closing_delim(_type, _otag, ctag), do: ctag

  defp build_token(:delimiter, raw, line, open_col) do
    case raw |> String.trim() |> String.split(~r/\s+/, trim: true) do
      [new_otag, new_ctag] -> {:set_delimiters, new_otag, new_ctag}
      _ -> raise SyntaxError, message: "invalid set-delimiter tag", line: line, column: open_col
    end
  end

  defp build_token(:comment, raw, line, open_col) do
    {:tag, :comment, {:comment, raw}, line, open_col}
  end

  defp build_token(:partial, raw, line, open_col) do
    {:tag, :partial, {:partial, String.trim(raw)}, line, open_col}
  end

  defp build_token(type, raw, line, open_col)
       when type in [:var, :unescaped, :unescaped_triple] do
    escaped? = type == :var
    keys = parse_keys(raw, line, open_col)
    {:tag, :var, {:var, keys, escaped?}, line, open_col}
  end

  defp build_token(type, raw, line, open_col) when type in [:section, :inverted, :close] do
    keys = parse_keys(raw, line, open_col)
    {:tag, type, {type, keys}, line, open_col}
  end

  defp parse_keys(raw, line, col) do
    trimmed = String.trim(raw)

    cond do
      trimmed == "" -> raise SyntaxError, message: "empty tag", line: line, column: col
      trimmed == "." -> ["."]
      true -> String.split(trimmed, ".")
    end
  end

  defp flush_text([], _line, _col, acc), do: acc

  defp flush_text(buffer, line, col, acc) do
    text = buffer |> Enum.reverse() |> IO.iodata_to_binary()

    # Text tokens carry the cursor position after the text. Only tags need
    # precise positions for error reporting, so this is sufficient.
    if text == "", do: acc, else: [{:text, text, line, col} | acc]
  end

  # Advance a {line, col} cursor past `text`.
  defp advance(text, line, col) do
    advance_chars(:binary.bin_to_list(text), line, col)
  end

  defp advance_chars([], line, col), do: {line, col}
  defp advance_chars([?\n | rest], line, _col), do: advance_chars(rest, line + 1, 1)
  defp advance_chars([_ | rest], line, col), do: advance_chars(rest, line, col + 1)

  defp standalone(tokens) do
    tokens
    |> Enum.with_index()
    |> Enum.reduce(List.to_tuple(tokens), fn {token, idx}, acc ->
      case token do
        {:tag, type, _payload, _l, _c} when type in @standalone_types ->
          maybe_trim_standalone(acc, idx)

        _ ->
          acc
      end
    end)
    |> Tuple.to_list()
    |> finalise_partials()
    |> Enum.reject(&drop_token?/1)
  end

  defp maybe_trim_standalone(tuple, idx) do
    prev = at(tuple, idx - 1)
    next = at(tuple, idx + 1)
    # A blank, newline-free neighbour only marks a line boundary when it sits at
    # the very edge of the template; otherwise there is another tag on the line.
    prev_is_first = idx - 1 == 0
    next_is_last = idx + 1 == tuple_size(tuple) - 1

    with {:ok, indent, new_prev} <- left_blank(prev, prev_is_first),
         {:ok, new_next} <- right_blank(next, next_is_last) do
      tuple = put(tuple, idx - 1, new_prev)
      tuple = put(tuple, idx + 1, new_next)
      attach_indent(tuple, idx, indent)
    else
      _ -> tuple
    end
  end

  # Is everything from the previous newline up to the tag whitespace?
  # Returns the captured indentation and the rewritten previous token.
  defp left_blank(nil, _first), do: {:ok, "", nil}

  defp left_blank({:text, text, l, c}, first?) do
    parts = String.split(text, "\n")
    last = List.last(parts)
    has_newline? = length(parts) > 1

    cond do
      not blank?(last) ->
        :no

      has_newline? ->
        head = parts |> Enum.drop(-1) |> Enum.join("\n")
        {:ok, last, {:text, head <> "\n", l, c}}

      first? or text == "" ->
        # No newline, but the line genuinely starts here: either this is the
        # leading token, or an adjacent standalone tag already consumed the
        # newline that preceded it (leaving an empty text token).
        {:ok, last, {:text, "", l, c}}

      true ->
        :no
    end
  end

  defp left_blank(_, _first), do: :no

  # Is everything from the tag to the next newline whitespace (then newline/EOF)?
  defp right_blank(nil, _last), do: {:ok, nil}

  defp right_blank({:text, text, l, c}, last?) do
    case split_at_newline(text) do
      {before, rest} ->
        if blank?(before), do: {:ok, {:text, rest, l, c}}, else: :no

      :no_newline ->
        # No newline after the tag: standalone only if nothing else follows
        # (end of template, or an adjacent tag already consumed the newline).
        if (last? or text == "") and blank?(text), do: {:ok, {:text, "", l, c}}, else: :no
    end
  end

  defp right_blank(_, _last), do: :no

  # Splits at and consumes the first newline (handling \r\n).
  # Returns the text before the newline and the text after it.
  defp split_at_newline(text) do
    case :binary.match(text, "\n") do
      :nomatch ->
        :no_newline

      {pos, _} ->
        before = binary_part(text, 0, pos)
        after_nl = binary_slice(text, pos + 1, byte_size(text))
        # If preceded by \r, drop it from `before`.
        before = String.replace_suffix(before, "\r", "")
        {before, after_nl}
    end
  end

  defp attach_indent(tuple, idx, indent) do
    case at(tuple, idx) do
      {:tag, :partial, {:partial, name}, l, c} ->
        put(tuple, idx, {:tag, :partial, {:partial, name, indent}, l, c})

      _ ->
        tuple
    end
  end

  # Partials that were never standalone still need an indent slot (empty).
  defp finalise_partials(tokens) do
    Enum.map(tokens, fn
      {:tag, :partial, {:partial, name}, l, c} -> {:tag, :partial, {:partial, name, ""}, l, c}
      other -> other
    end)
  end

  defp drop_token?({:tag, :comment, _, _, _}), do: true
  defp drop_token?({:tag, :delimiter, _, _, _}), do: true
  defp drop_token?({:text, "", _, _}), do: true
  defp drop_token?(_), do: false

  defp blank?(s), do: String.trim_leading(s, " ") |> String.trim_leading("\t") == ""

  defp at(tuple, idx) when idx >= 0 and idx < tuple_size(tuple), do: elem(tuple, idx)
  defp at(_tuple, _idx), do: nil

  defp put(tuple, idx, value) when idx >= 0 and idx < tuple_size(tuple),
    do: put_elem(tuple, idx, value)

  defp put(tuple, _idx, _value), do: tuple
end
