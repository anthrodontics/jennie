defmodule Jennie.SyntaxError do
  defexception [:message, :line, :column]

  @impl true
  def message(exception) do
    "Error: line #{exception.line}:column #{exception.column}: #{exception.message}"
  end
end
