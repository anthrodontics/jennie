defmodule Jennie.Template do
  @moduledoc """
  A compiled template: the cacheable artifact produced by `Jennie.compile/2`.

  Holds the parsed AST so repeated renders skip tokenising and parsing.
  """

  @enforce_keys [:ast]
  defstruct ast: [], source: nil

  @type t :: %__MODULE__{ast: [tuple()], source: String.t() | nil}
end
