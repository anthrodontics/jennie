defmodule Jennie do
  def render(source, data \\ %{}) do
    Jennie.Compiler.compile(source, data, [])
  end
end
