defmodule Jennie.Compiler do
  @default_engine Jennie.Engine

  def compile(source, assigns, opts) do
    line = opts[:line] || 1
    column = 1
    indentation = opts[:indentation] || 0

    tokeniser_options = %{indentation: indentation}

    case Jennie.Tokeniser.tokenise(source, line, column, tokeniser_options) do
      {:ok, tokens} ->
        state = %{
          engine: opts[:engine] || @default_engine,
          line: line,
          assigns: assigns,
          scope: []
        }

        init = state.engine.init()

        generate_buffer(tokens, init, state)

      {:error, line, column, message} ->
        raise Jennie.SyntaxError,
          message: message,
          line: line,
          column: column
    end
  end

  defp generate_buffer(rest, buffer, %{scope: [{name, children} | _] = scope} = state)
       when is_list(children) do
    {found?, tokens} =
      Enum.reduce_while(rest, {false, []}, fn look_ahead, {_, acc} ->
        case look_ahead do
          {:tag, _, _, ~c"/", [^name]} ->
            {:halt, {true, Enum.reverse(acc)}}

          token ->
            {:cont, {false, [token | acc]}}
        end
      end)

    if found? == false do
      [{_, line, column, _, _} | _rest] = tokens
      error("Section tag is not closed!", line, column)
    end

    scope = Enum.drop(scope, 1)

    new_buffer =
      Enum.reduce(children, %{binary: []}, fn child, %{binary: binary} = acc ->
        assigns = merge(state.assigns, child)

        %{binary: new} =
          generate_buffer(tokens, state.engine.init(), %{state | scope: scope, assigns: assigns})

        %{acc | binary: new ++ binary}
      end)

    # need to remove all the look ahead tokens before continuing.
    buffer = %{buffer | binary: new_buffer.binary ++ buffer.binary}
    drop_amount = length(tokens) + 1
    generate_buffer(Enum.drop(rest, drop_amount), buffer, %{state | scope: scope})
  end

  defp generate_buffer([{:text, _, _, chars} | rest], buffer, state) do
    buffer = state.engine.handle_text(buffer, chars, state)
    generate_buffer(rest, buffer, state)
  end

  defp generate_buffer([{:whitespace, _, _, chars} | rest], buffer, state) do
    buffer = state.engine.handle_text(buffer, chars, state)
    generate_buffer(rest, buffer, state)
  end

  defp generate_buffer([{:new_line, _, _} | rest], buffer, state) do
    buffer = state.engine.handle_text(buffer, "\n", state)
    generate_buffer(rest, buffer, state)
  end

  defp generate_buffer([{:tag, _, _, ~c"", expr} | rest], buffer, state) do
    buffer = state.engine.handle_tag(buffer, expr, state)
    generate_buffer(rest, buffer, state)
  end

  defp generate_buffer([{:tag, _, _, ~c"#", expr} | rest], buffer, %{scope: scope} = state) do
    %{dynamic: context} = buffer = state.engine.handle_context(buffer, expr, state)

    generate_buffer(rest, buffer, %{state | scope: [context | scope]})
  end

  defp generate_buffer([{:tag, line, column, ~c"/", _}], _buffer, %{scope: scope})
       when length(scope) > 0,
       do:
         error(
           "Cannot close section, because corresponding opening section is missing",
           line,
           column
         )

  defp generate_buffer(
         [{:tag, line, column, ~c"/", expr} | rest],
         buffer,
         %{scope: [{scope_name, _} | stack]} = state
       ) do
    if scope_name == Enum.join(expr, ".") do
      generate_buffer(rest, buffer, %{state | scope: stack})
    else
      raise Jennie.SyntaxError,
        message: "Closing section prematurely",
        line: line,
        column: column
    end
  end

  defp generate_buffer([], buffer, _state), do: buffer

  defp generate_buffer([{:eof, line, column}], _buffer, %{scope: scope}) when length(scope) > 0,
    do: error("A section tag is still open", line, column)

  defp generate_buffer([{:eof, _, _}], buffer, %{scope: []} = state) do
    state.engine.handle_body(buffer)
  end

  defp generate_buffer([{:eof, line, column}], _buffer, _state),
    do: error("unexpected end of string, expected a closing {{/<thing>}}", line, column)

  defp merge(assigns, child) when is_map(child), do: Map.merge(assigns, child)
  defp merge(assigns, child), do: merge(assigns, %{"." => child})

  defp error(message, line, column) do
    raise Jennie.SyntaxError,
      message: message,
      line: line,
      column: column
  end
end
