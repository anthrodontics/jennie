defmodule Jennie do
  @doc """
  Renders template by substituting tags
  
    ## Examples
    
    iex> Jennie.render("Hello {{guest}}!", %{"guest" => "World"})
  """
  def render(source, data \\ %{}, opts \\ [])

  def render(source, data, opts) when is_map(data) do
    Jennie.Compiler.compile(source, data, opts)
  end

  def render(source, data, opts) do
    Jennie.Compiler.compile(source, %{"default" => data}, opts)
  end
  
  @doc """
  Finds all tokens in the template
  
    ## Examples
  
    iex> Jennie.scan("{{name}}")
    ["name"]
    
    iex> Jennie.scan("{{#family}}{{.}}{{/family}}")
    ["family"]
  """
  def scan(source) do
    {:ok, tokens} = Jennie.Tokeniser.tokenise(source, 1, 1, %{indentation: 0})
    
    Enum.filter(tokens, fn token ->
      case token do
        {:tag, _, _, ~c"", ["."]} -> false
        {:tag, _, _, ~c"", _} -> true
        {:tag, _, _, ~c"#", _} -> true
        _ -> false
      end
    end)
    |> Enum.reduce([], fn {_, _, _, _, [var]}, acc ->
      [var | acc]
    end)
    |> Enum.reverse()
  end
  
  @doc """
  Finds all tokens in the template
  
    ## Examples
  
    iex> Jennie.missing?("{{name}}", %{})
    ["name"]
    
    iex> Jennie.missing?("{{my_love_life}}", %{}) == ["my_love_life"]
    true
  """
  def missing?(source, data) do
    source_tags = scan(source)
    Enum.filter(source_tags, fn tag ->
      Map.get(data, tag) == nil
    end)
  end
end