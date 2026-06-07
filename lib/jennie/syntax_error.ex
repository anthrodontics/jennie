defmodule Jennie.SyntaxError do
  @moduledoc false

  defexception [:message, :line, :column]

  @type t :: %__MODULE__{message: String.t(), line: pos_integer(), column: pos_integer()}

  @impl true
  def message(%{message: message, line: line, column: column}) do
    "Jennie syntax error on line #{line}, column #{column}: #{message}"
  end
end
