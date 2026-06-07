defmodule Jennie.Renderer do
  @moduledoc """
  Walks a parsed AST against a context stack and produces the output binary.
  """

  alias Jennie.{Parser, Tokeniser, Utils}

  @empty_section [nil, false]

  @doc """
  Render `ast` with `data` and `opts`. Returns a binary.
  """
  @spec render([tuple()], term(), keyword()) :: binary()
  def render(ast, data, opts) do
    engine = Keyword.get(opts, :engine, Jennie.Engine)

    state = %{
      stack: [Utils.normalise(data)],
      escape: Keyword.get(opts, :escape, &html_escape/1),
      partials: Keyword.get(opts, :partials, %{}),
      raise_on_missing_partial: Keyword.get(opts, :raise_on_missing_partial, false),
      ignore_nil: Keyword.get(opts, :ignore_nil, false),
      engine: engine,
      acc: engine.init()
    }

    state = render_nodes(ast, state)
    engine.handle_body(state.acc)
  end

  defp render_nodes(nodes, state), do: Enum.reduce(nodes, state, &render_node/2)

  defp render_node({:text, text}, state), do: emit(state, text)

  defp render_node({:var, keys, escaped?}, state) do
    case resolve(keys, state.stack) do
      :not_found ->
        if state.ignore_nil, do: emit(state, reemit_var(keys, escaped?)), else: state

      {:found, value} ->
        rendered = stringify(value, state)
        emit(state, if(escaped?, do: state.escape.(rendered), else: rendered))
    end
  end

  defp render_node({:section, keys, children}, state) do
    case resolve(keys, state.stack) do
      :not_found ->
        if state.ignore_nil, do: emit(state, reemit_section(keys, children)), else: state

      {:found, value} ->
        render_section(value, children, state)
    end
  end

  defp render_node({:inverted, keys, children}, state) do
    render? =
      case resolve(keys, state.stack) do
        :not_found -> true
        {:found, value} -> falsey?(value)
      end

    if render?, do: render_nodes(children, state), else: state
  end

  defp render_node({:partial, name, indent}, state) do
    case resolve_partial(name, state) do
      nil ->
        if state.raise_on_missing_partial do
          raise ArgumentError, "could not resolve partial #{inspect(name)}"
        else
          state
        end

      source ->
        out = render_string(indent_source(source, indent), state.stack, state)
        emit(state, out)
    end
  end

  # A function in section position is a lambda (arity 1, receives raw inner
  # text) or a thunk (arity 0, computes the section value).
  defp render_section(value, children, state) when is_function(value) do
    case fun_arity(value) do
      1 ->
        raw = to_source(children)
        out = render_string(to_string(value.(raw)), state.stack, state)
        emit(state, out)

      0 ->
        render_section(value.(), children, state)

      arity ->
        raise ArgumentError,
              "section lambda must have arity 0 or 1, got arity #{arity}"
    end
  end

  defp render_section(value, _children, state) when value in @empty_section, do: state
  defp render_section([], _children, state), do: state

  defp render_section(list, children, state) when is_list(list) do
    Enum.reduce(list, state, fn item, st ->
      pushed = %{st | stack: [Utils.normalise(item) | state.stack]}
      rendered = render_nodes(children, pushed)
      %{rendered | stack: state.stack}
    end)
  end

  defp render_section(value, children, state) do
    pushed = %{state | stack: [Utils.normalise(value) | state.stack]}
    rendered = render_nodes(children, pushed)
    %{rendered | stack: state.stack}
  end

  # Implicit iterator: the innermost context value.
  defp resolve(["."], [current | _]), do: {:found, current}
  defp resolve(["."], []), do: :not_found

  # Dotted names: the first segment is resolved against the whole stack; the
  # remaining segments walk *only* into that result (mustache dotted semantics).
  defp resolve([first | rest], stack) do
    case lookup_in_stack(first, stack) do
      :not_found -> :not_found
      {:found, value} -> walk(value, rest)
    end
  end

  defp lookup_in_stack(_key, []), do: :not_found

  defp lookup_in_stack(key, [frame | rest]) do
    if is_map(frame) and Map.has_key?(frame, key) do
      {:found, Map.get(frame, key)}
    else
      lookup_in_stack(key, rest)
    end
  end

  defp walk(value, []), do: {:found, value}

  defp walk(value, [key | rest]) when is_map(value) do
    normalised = Utils.normalise(value)

    case Map.fetch(normalised, key) do
      {:ok, next} -> walk(next, rest)
      :error -> :not_found
    end
  end

  defp walk(_value, _keys), do: :not_found

  defp resolve_partial(name, %{partials: partials}) when is_map(partials) do
    Map.get(partials, name)
  end

  defp resolve_partial(name, %{partials: fun}) when is_function(fun, 1), do: fun.(name)
  defp resolve_partial(_name, _state), do: nil

  # Render a fresh source string against the given stack, reusing the same
  # engine/config. Used by partials and lambda expansion.
  defp render_string(source, stack, state) do
    {:ok, tokens} = Tokeniser.tokenise(source)
    ast = Parser.parse(tokens)
    sub = %{state | acc: state.engine.init(), stack: stack}
    out = render_nodes(ast, sub)
    state.engine.handle_body(out.acc)
  end

  defp stringify(value, state) when is_function(value) do
    case fun_arity(value) do
      0 -> render_string(to_string(value.()), state.stack, state)
      arity -> raise ArgumentError, "interpolation lambda must have arity 0, got arity #{arity}"
    end
  end

  defp stringify(value, _state), do: safe_string(value)

  defp emit(state, iodata), do: %{state | acc: state.engine.handle_text(state.acc, iodata)}

  defp falsey?(value), do: value in @empty_section or value == []

  defp fun_arity(fun), do: fun |> :erlang.fun_info(:arity) |> elem(1)

  defp safe_string(nil), do: ""
  defp safe_string(value) when is_binary(value), do: value
  defp safe_string(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_string(value) when is_integer(value) or is_float(value), do: to_string(value)
  defp safe_string(value) when is_list(value), do: inspect(value)
  defp safe_string(value), do: inspect(value)

  @doc false
  def html_escape(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  def html_escape(value), do: html_escape(safe_string(value))

  # Re-serialise AST back to mustache source (for lambda inner text and the
  # `ignore_nil` re-emit path).
  defp to_source(nodes) when is_list(nodes), do: Enum.map_join(nodes, "", &node_source/1)

  defp node_source({:text, text}), do: text
  defp node_source({:var, keys, true}), do: "{{" <> Enum.join(keys, ".") <> "}}"
  defp node_source({:var, keys, false}), do: "{{{" <> Enum.join(keys, ".") <> "}}}"

  defp node_source({:section, keys, children}) do
    name = Enum.join(keys, ".")
    "{{#" <> name <> "}}" <> to_source(children) <> "{{/" <> name <> "}}"
  end

  defp node_source({:inverted, keys, children}) do
    name = Enum.join(keys, ".")
    "{{^" <> name <> "}}" <> to_source(children) <> "{{/" <> name <> "}}"
  end

  defp node_source({:partial, name, _indent}), do: "{{>" <> name <> "}}"

  defp reemit_var(keys, true), do: "{{" <> Enum.join(keys, ".") <> "}}"
  defp reemit_var(keys, false), do: "{{{" <> Enum.join(keys, ".") <> "}}}"

  defp reemit_section(keys, children), do: node_source({:section, keys, children})

  # Apply standalone-partial indentation to the partial *source* (matching
  # Ruby's `gsub(/^/, indent)`, which does not indent the trailing empty line).
  defp indent_source("", _indent), do: ""
  defp indent_source(source, ""), do: source

  defp indent_source(source, indent) do
    indented = indent <> String.replace(source, "\n", "\n" <> indent)

    if String.ends_with?(source, "\n") do
      String.replace_suffix(indented, "\n" <> indent, "\n")
    else
      indented
    end
  end
end
