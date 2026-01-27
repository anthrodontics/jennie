defmodule Jennie do
  @moduledoc """
  A Jennie template parser and renderer implementing the Jennie spec v1.3.0.
  Supports variables, sections, inverted sections, comments, partials, and custom delimiters.
  """

  @doc """
  Renders a Jennie template with the given context.

  ## Examples

      iex> Jennie.render("Hello {{name}}", %{"name" => "World"})
      "Hello World"

      iex> Jennie.render("{{#show}}Yes{{/show}}", %{"show" => true})
      "Yes"
  """
  def render(template, context, partials \\ %{}) do
    tokens = parse(template)
    render_tokens(tokens, context, partials, {"{{", "}}"})
  end

  @doc """
  Parses a Jennie template into tokens.
  """
  def parse(template, delimiters \\ {"{{", "}}"}) do
    parse_template(template, [], delimiters)
  end

  # Parser implementation
  defp parse_template(template, acc, delimiters) do
    {open, close} = delimiters

    case find_next_tag(template, open, close) do
      {:ok, before, tag_content, after_tag, new_delimiters} ->
        tokens = if before != "", do: [{:text, before} | acc], else: acc

        case parse_tag(tag_content, after_tag, new_delimiters || delimiters) do
          {:section, name, rest, inner_tokens} ->
            parse_template(
              rest,
              [{:section, name, Enum.reverse(inner_tokens)} | tokens],
              new_delimiters || delimiters
            )

          {:inverted, name, rest, inner_tokens} ->
            parse_template(
              rest,
              [{:inverted, name, Enum.reverse(inner_tokens)} | tokens],
              new_delimiters || delimiters
            )

          {:token, token, new_delims} ->
            parse_template(after_tag, [token | tokens], new_delims || delimiters)
        end

      :not_found ->
        tokens = if template != "", do: [{:text, template} | acc], else: acc
        Enum.reverse(tokens)
    end
  end

  defp find_next_tag(template, open, close) do
    case String.split(template, open, parts: 2) do
      [before, rest] ->
        case String.split(rest, close, parts: 2) do
          [tag_content, after_tag] ->
            # Check for set delimiter tag
            new_delimiters =
              if String.starts_with?(tag_content, "=") and String.ends_with?(tag_content, "=") do
                parse_delimiter(tag_content)
              end

            {:ok, before, tag_content, after_tag, new_delimiters}

          _ ->
            :not_found
        end

      _ ->
        :not_found
    end
  end

  defp parse_delimiter(content) do
    content = content |> String.trim_leading("=") |> String.trim_trailing("=") |> String.trim()

    case String.split(content, " ", parts: 2) do
      [new_open, new_close] -> {new_open, new_close}
      _ -> nil
    end
  end

  defp parse_tag(content, rest, delimiters) do
    cond do
      # Comment
      String.starts_with?(content, "!") ->
        {:token, {:comment, String.trim_leading(content, "!")}, delimiters}

      # Partial
      String.starts_with?(content, ">") ->
        name = content |> String.trim_leading(">") |> String.trim()
        {:token, {:partial, name}, delimiters}

      # Inverted section
      String.starts_with?(content, "^") ->
        name = content |> String.trim_leading("^") |> String.trim()
        {inner_tokens, remaining} = parse_until_closing(rest, name, delimiters)
        {:inverted, name, remaining, inner_tokens}

      # Section
      String.starts_with?(content, "#") ->
        name = content |> String.trim_leading("#") |> String.trim()
        {inner_tokens, remaining} = parse_until_closing(rest, name, delimiters)
        {:section, name, remaining, inner_tokens}

      # Unescaped variable (triple Jennie or &)
      String.starts_with?(content, "{") and String.ends_with?(content, "}") ->
        name = content |> String.trim_leading("{") |> String.trim_trailing("}") |> String.trim()
        {:token, {:variable, name, false}, delimiters}

      String.starts_with?(content, "&") ->
        name = content |> String.trim_leading("&") |> String.trim()
        {:token, {:variable, name, false}, delimiters}

      # Set delimiter
      String.starts_with?(content, "=") and String.ends_with?(content, "=") ->
        new_delimiters = parse_delimiter(content)
        {:token, {:delimiter, elem(new_delimiters, 0), elem(new_delimiters, 1)}, new_delimiters}

      # Regular variable
      true ->
        name = String.trim(content)
        {:token, {:variable, name, true}, delimiters}
    end
  end

  defp parse_until_closing(template, section_name, delimiters) do
    {open, close} = delimiters
    closing_tag = "/#{section_name}"

    parse_section_content(template, [], section_name, delimiters, 0)
  end

  defp parse_section_content(template, acc, section_name, delimiters, depth) do
    {open, close} = delimiters

    case find_next_tag(template, open, close) do
      {:ok, before, tag_content, after_tag, new_delimiters} ->
        tokens = if before != "", do: [{:text, before} | acc], else: acc
        tag_name = String.trim(tag_content)

        cond do
          # Found closing tag at depth 0
          String.starts_with?(tag_content, "/") and depth == 0 ->
            name = tag_content |> String.trim_leading("/") |> String.trim()

            if name == section_name do
              {Enum.reverse(tokens), after_tag}
            else
              parse_section_content(
                after_tag,
                [{:text, "#{open}#{tag_content}#{close}"} | tokens],
                section_name,
                new_delimiters || delimiters,
                depth
              )
            end

          # Found nested section opening
          String.starts_with?(tag_content, "#") or String.starts_with?(tag_content, "^") ->
            case parse_tag(tag_content, after_tag, new_delimiters || delimiters) do
              {:section, name, rest, inner_tokens} ->
                parse_section_content(
                  rest,
                  [{:section, name, Enum.reverse(inner_tokens)} | tokens],
                  section_name,
                  new_delimiters || delimiters,
                  depth
                )

              {:inverted, name, rest, inner_tokens} ->
                parse_section_content(
                  rest,
                  [{:inverted, name, Enum.reverse(inner_tokens)} | tokens],
                  section_name,
                  new_delimiters || delimiters,
                  depth
                )
            end

          # Found closing tag at depth > 0
          String.starts_with?(tag_content, "/") ->
            parse_section_content(
              after_tag,
              [{:text, "#{open}#{tag_content}#{close}"} | tokens],
              section_name,
              new_delimiters || delimiters,
              depth - 1
            )

          # Regular tag
          true ->
            case parse_tag(tag_content, after_tag, new_delimiters || delimiters) do
              {:token, token, new_delims} ->
                parse_section_content(
                  after_tag,
                  [token | tokens],
                  section_name,
                  new_delims || delimiters,
                  depth
                )
            end
        end

      :not_found ->
        {Enum.reverse(if template != "", do: [{:text, template} | acc], else: acc), ""}
    end
  end

  # Renderer implementation
  defp render_tokens(tokens, context, partials, delimiters) do
    IO.inspect(tokens)

    tokens
    |> Enum.map(&render_token(&1, context, partials, delimiters))
    |> Enum.join()
  end

  defp render_token({:text, text}, _context, _partials, _delimiters), do: text

  defp render_token({:comment, _}, _context, _partials, _delimiters), do: ""

  defp render_token({:delimiter, _, _}, _context, _partials, _delimiters), do: ""

  defp render_token({:variable, name, escape}, context, _partials, _delimiters) do
    value = lookup(name, context)
    value = resolve_value(value, context)

    cond do
      is_nil(value) -> ""
      escape -> html_escape(to_string(value))
      true -> to_string(value)
    end
  end

  defp render_token({:section, name, inner_tokens}, context, partials, delimiters) do
    value = lookup(name, context)
    value = resolve_value(value, context)

    cond do
      is_function(value) ->
        # Lambda support - pass unrendered block
        raw_block = tokens_to_string(inner_tokens, delimiters)
        result = value.(raw_block)
        render(to_string(result), context, partials)

      is_list(value) and value != [] ->
        # Non-empty list - render once per item
        Enum.map(value, fn item ->
          # For primitive values, the item becomes the context for "."
          # For maps, merge with parent context
          new_context = if is_map(item), do: Map.merge(context, item), else: item
          render_tokens(inner_tokens, new_context, partials, delimiters)
        end)
        |> Enum.join()

      is_map(value) ->
        # Non-false value - use as context
        new_context = create_context(value, context)
        render_tokens(inner_tokens, new_context, partials, delimiters)

      value == true ->
        # True - render with current context
        render_tokens(inner_tokens, context, partials, delimiters)

      true ->
        # False or empty list - don't render
        ""
    end
  end

  defp render_token({:inverted, name, inner_tokens}, context, partials, delimiters) do
    value = lookup(name, context)
    value = resolve_value(value, context)

    cond do
      is_nil(value) or value == false or value == [] ->
        render_tokens(inner_tokens, context, partials, delimiters)

      true ->
        ""
    end
  end

  defp render_token({:partial, name}, context, partials, delimiters) do
    case Map.get(partials, name) do
      nil -> ""
      partial_template -> render(partial_template, context, partials)
    end
  end

  # Helper to convert tokens back to string for lambda support
  defp tokens_to_string(tokens, {open, close}) do
    Enum.map(tokens, fn
      {:text, text} ->
        text

      {:variable, name, true} ->
        "#{open}#{name}#{close}"

      {:variable, name, false} ->
        "#{open}&#{name}#{close}"

      {:section, name, inner} ->
        "#{open}##{name}#{close}#{tokens_to_string(inner, {open, close})}#{open}/#{name}#{close}"

      {:inverted, name, inner} ->
        "#{open}^#{name}#{close}#{tokens_to_string(inner, {open, close})}#{open}/#{name}#{close}"

      _ ->
        ""
    end)
    |> Enum.join()
  end

  # Context lookup with dotted name support
  defp lookup(".", context), do: context

  defp lookup(name, context) do
    case String.split(name, ".") do
      [single] -> get_value(context, single)
      parts -> lookup_dotted(parts, context)
    end
  end

  defp lookup_dotted([], value), do: value

  defp lookup_dotted([key | rest], context) do
    case get_value(context, key) do
      nil -> nil
      value -> lookup_dotted(rest, value)
    end
  end

  defp get_value(context, key) when is_map(context) do
    Map.get(context, key) || Map.get(context, String.to_atom(key))
  end

  defp get_value(_context, _key), do: nil

  defp resolve_value(value, context) when is_function(value, 0) do
    value.()
  end

  defp resolve_value(value, _context), do: value

  defp create_context(new_context, parent) when is_map(new_context) do
    Map.merge(parent, new_context)
  end

  defp create_context(value, _parent), do: value

  defp html_escape(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
