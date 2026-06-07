defmodule Jennie.Parser do
  @moduledoc """
  Converts tokens into an Abstract Syntax Tree.

  AST node types:

    * `{:text, binary}`
    * `{:var, keys, escaped?}`
    * `{:section, keys, children}`
    * `{:inverted, keys, children}`
    * `{:partial, name, indent}`

  """

  alias Jennie.SyntaxError

  @doc """
  Parse tokens into a list of AST nodes.
  """
  @spec parse([tuple()]) :: [tuple()]
  def parse(tokens) do
    {nodes, _rest} = parse_nodes(tokens, nil)
    nodes
  end

  # Parses nodes until it hits the closing tag for `open` (a `{keys, line, col}`
  # tuple) or the end of input. Returns `{nodes, remaining_tokens}`.
  defp parse_nodes(tokens, open) do
    do_parse(tokens, open, [])
  end

  defp do_parse([], nil, acc), do: {Enum.reverse(acc), []}

  defp do_parse([], {keys, line, col}, _acc) do
    raise SyntaxError,
      message: "unclosed section #{inspect(Enum.join(keys, "."))}",
      line: line,
      column: col
  end

  defp do_parse([{:text, text, _l, _c} | rest], open, acc) do
    do_parse(rest, open, [{:text, text} | acc])
  end

  defp do_parse([{:tag, :var, {:var, keys, escaped?}, _l, _c} | rest], open, acc) do
    do_parse(rest, open, [{:var, keys, escaped?} | acc])
  end

  defp do_parse([{:tag, :partial, {:partial, name, indent}, _l, _c} | rest], open, acc) do
    do_parse(rest, open, [{:partial, name, indent} | acc])
  end

  defp do_parse([{:tag, type, {type, keys}, line, col} | rest], open, acc)
       when type in [:section, :inverted] do
    {children, rest2} = parse_nodes(rest, {keys, line, col})
    node = {type, keys, children}
    do_parse(rest2, open, [node | acc])
  end

  defp do_parse([{:tag, :close, {:close, keys}, line, col} | rest], open, acc) do
    case open do
      nil ->
        raise SyntaxError,
          message: "closing tag #{inspect(Enum.join(keys, "."))} has no matching opening section",
          line: line,
          column: col

      {open_keys, _ol, _oc} ->
        if keys == open_keys do
          {Enum.reverse(acc), rest}
        else
          raise SyntaxError,
            message:
              "mismatched closing tag: expected #{inspect(Enum.join(open_keys, "."))}, got #{inspect(Enum.join(keys, "."))}",
            line: line,
            column: col
        end
    end
  end
end
