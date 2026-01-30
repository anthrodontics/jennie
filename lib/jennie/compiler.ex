defmodule Jennie.Compiler do
  @default_engine Jennie.Engine

  def compile(source, assigns, opts) do
    line = opts[:line] || 1
    column = 1
    indentation = opts[:indentation] || 0
    trim = opts[:trim] || false

    tokeniser_options = %{trim: trim, indentation: indentation}

    case Jennie.Tokeniser.tokenise(source, line, column, tokeniser_options) do
      {:ok, tokens} ->
        state = %{
          engine: opts[:engine] || @default_engine,
          line: line,
          assigns: assigns,
          scope: []
        }

        init = state.engine.init(opts)

        generate_buffer(tokens, init, state)

      {:error, line, column, message} ->
        raise Jennie.SyntaxError,
          message: message,
          line: line,
          column: column
    end
  end

  defp generate_buffer([{:text, _, _, chars} | rest], buffer, state) do
    buffer = state.engine.handle_text(buffer, chars)
    generate_buffer(rest, buffer, state)
  end

  defp generate_buffer([{:whitespace, _, _, chars} | rest], buffer, state) do
    buffer = state.engine.handle_text(buffer, chars)
    generate_buffer(rest, buffer, state)
  end

  defp generate_buffer([{:new_line, _, _} | rest], buffer, state) do
    buffer = state.engine.handle_text(buffer, "\n")
    generate_buffer(rest, buffer, state)
  end

  defp generate_buffer([{:tag, _, _, ~c"", expr} | rest], buffer, state) do
    buffer = state.engine.handle_tag(buffer, expr, state)
    generate_buffer(rest, buffer, state)
  end

  defp generate_buffer([{:tag, _, _, ~c"#", expr} | rest], buffer, %{scope: scope} = state) do
    buffer = state.engine.handle_context(buffer, expr, state)
    generate_buffer(rest, buffer, %{state | scope: [Enum.join(expr, ".") | scope]})
  end

  defp generate_buffer([{:tag, line, column, ~c"/", _}], _buffer, %{scope: scope})
       when length(scope) > 0 do
    raise Jennie.SyntaxError,
      message: "Cannot close section, because corresponding opening section is missing",
      line: line,
      column: column
  end

  defp generate_buffer(
         [{:tag, line, column, ~c"/", expr} | rest],
         buffer,
         %{scope: [head | tail]} = state
       ) do
    if head == Enum.join(expr, ".") do
      buffer = state.engine.pop_context(buffer)
      generate_buffer(rest, buffer, %{state | scope: tail})
    else
      raise Jennie.SyntaxError,
        message: "Closing section prematurely",
        line: line,
        column: column
    end
  end

  defp generate_buffer([{:eof, line, column}], _buffer, %{scope: scope}) when length(scope) > 0 do
    raise Jennie.SyntaxError,
      message: "A section tag is still open",
      line: line,
      column: column
  end

  defp generate_buffer([{:eof, _, _}], buffer, %{scope: []} = state) do
    state.engine.handle_body(buffer)
  end

  defp generate_buffer([{:eof, line, column}], _buffer, _state) do
    raise Jennie.SyntaxError,
      message: "unexpected end of string, expected a closing {{/<thing>}}",
      line: line,
      column: column
  end

  # defp process() do
  #   if is_map(eval) do
  #     raise Jennie.SyntaxError,
  #       message: "Incomplete expansion of tag `#{Enum.join(expr, ".")}`.",
  #       line: line,
  #       column: column
  #   end
  # end
end
