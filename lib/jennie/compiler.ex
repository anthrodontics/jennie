defmodule Jennie.Compiler do
  def compile(source, data, opts) do
    line = opts[:line] || 1
    column = 1
    indentation = opts[:indentation] || 0
    trim = opts[:trim] || false

    tokeniser_options = %{trim: trim, indentation: indentation}

    case Jennie.Tokeniser.tokenise(source, line, column, tokeniser_options) do
      {:ok, tokens} ->
        # state = %{
        #   line: line,
        #   start_line: nil,
        #   start_column: nil
        # }

        Enum.reduce(tokens, "", fn token, acc ->
          acc <> generate_buffer(token, data)
        end)

      {:error, line, column, message} ->
        raise Jennie.SyntaxError, line: line, column: column, message: message
    end
  end

  defp generate_buffer({:text, _, _, charlist}, _data), do: to_string(charlist)

  defp generate_buffer({:tag, _, _, _, charlist}, data) do
    term = to_string(charlist)
    field = String.trim(term)
    String.replace(term, term, Map.get(data, field, ""))
  end

  defp generate_buffer({:eof, _, _}, _data) do
    ""
  end
end
