defmodule Jennie do
  def render(source, data \\ %{})

  def render(source, data) when is_map(data) do
    Jennie.Compiler.compile(source, data, trim: false)
  end

  def render(source, data) do
    Jennie.Compiler.compile(source, %{"default" => data}, trim: true)
  end
end
