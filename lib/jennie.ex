defmodule Jennie do
  @moduledoc """
  Jennie — logic-less templates inspired by Moustache.

  ## Quick start

      iex> Jennie.render("Hello {{name}}!", %{"name" => "World"})
      "Hello World!"

      iex> Jennie.render("{{x}}", %{"x" => "<b>"})
      "&lt;b&gt;"

      iex> Jennie.render("{{{x}}}", %{"x" => "<b>"})
      "<b>"

  ## Compile once, render many

      {:ok, tpl} = Jennie.compile("Hi {{name}}")
      Jennie.render(tpl, %{"name" => "A"})
      Jennie.render(tpl, %{"name" => "B"})

  ## Options

    * `:escape` — a `(binary -> iodata)` escaper (default: HTML)
    * `:partials` — a `%{name => source}` map or `(name -> source | nil)` fun
    * `:raise_on_missing_partial` — raise instead of rendering `""` (default `false`)
    * `:engine` — output engine module (default `Jennie.Engine`)
    * `:ignore_nil` — leave tags whose keys are absent in place (default `false`)
  """

  alias Jennie.{Parser, Renderer, Template, Tokeniser}

  @doc """
  Compile `source` into a reusable `Jennie.Template`.

  Returns `{:ok, template}` or `{:error, %Jennie.SyntaxError{}}`.
  """
  @spec compile(String.t(), keyword()) :: {:ok, Template.t()} | {:error, Jennie.SyntaxError.t()}
  def compile(source, _opts \\ []) when is_binary(source) do
    {:ok, tokens} = Tokeniser.tokenise(source)
    ast = Parser.parse(tokens)
    {:ok, %Template{ast: ast, source: source}}
  rescue
    error in Jennie.SyntaxError -> {:error, error}
  end

  @doc """
  Like `compile/2` but raises `Jennie.SyntaxError` on failure.
  """
  @spec compile!(String.t(), keyword()) :: Template.t()
  def compile!(source, opts \\ []) when is_binary(source) do
    case compile(source, opts) do
      {:ok, template} -> template
      {:error, error} -> raise error
    end
  end

  @doc """
  Render a template against `data`.

  `source_or_template` may be a raw string or a pre-compiled `Jennie.Template`.
  Non-map `data` (a scalar, list, or struct) is rendered as the top-level
  implicit-iterator context, reachable via `{{.}}`.

  ## Examples

      iex> Jennie.render("{{.}} miles", 85)
      "85 miles"

      iex> Jennie.render("{{#.}}({{value}}){{/.}}", [%{"value" => "a"}, %{"value" => "b"}])
      "(a)(b)"
  """
  @spec render(String.t() | Template.t(), term(), keyword()) :: binary()
  def render(source_or_template, data \\ %{}, opts \\ [])

  def render(%Template{ast: ast}, data, opts) do
    Renderer.render(ast, data, opts)
  end

  def render(source, data, opts) when is_binary(source) do
    %Template{ast: ast} = compile!(source, opts)
    Renderer.render(ast, data, opts)
  end

  @doc """
  List the names of every tag in `source` that references the data — variables,
  unescaped tags, sections, and inverted sections. Comments, partials, and
  delimiter tags are excluded, as is the implicit iterator `{{.}}`. Names are
  deduplicated while preserving first-seen order.

  ## Examples

      iex> Jennie.scan("{{a}}{{#b}}{{c}}{{/b}}")
      ["a", "b", "c"]
  """
  @spec scan(String.t()) :: [String.t()]
  def scan(source) when is_binary(source) do
    {:ok, tokens} = Tokeniser.tokenise(source)

    tokens
    |> Parser.parse()
    |> collect_names([])
    |> Enum.reverse()
    |> Enum.uniq()
  end

  @doc """
  Names referenced by `source` whose top-level key is absent from `data`.

  ## Examples

      iex> Jennie.missing?("{{a}}{{b}}", %{"a" => 1})
      ["b"]
  """
  @spec missing?(String.t(), term()) :: [String.t()]
  def missing?(source, data) when is_binary(source) do
    normalised = Jennie.Utils.normalise(data)
    present = if is_map(normalised), do: normalised, else: %{}

    source
    |> scan()
    |> Enum.reject(fn name ->
      [head | _] = String.split(name, ".")
      Map.has_key?(present, head)
    end)
  end

  defp collect_names([], acc), do: acc

  defp collect_names([{:text, _} | rest], acc), do: collect_names(rest, acc)

  defp collect_names([{:var, ["."], _} | rest], acc), do: collect_names(rest, acc)

  defp collect_names([{:var, keys, _} | rest], acc) do
    collect_names(rest, [Enum.join(keys, ".") | acc])
  end

  defp collect_names([{:partial, _name, _indent} | rest], acc), do: collect_names(rest, acc)

  defp collect_names([{type, keys, children} | rest], acc) when type in [:section, :inverted] do
    acc = [Enum.join(keys, ".") | acc]
    acc = collect_names(children, acc)
    collect_names(rest, acc)
  end
end
