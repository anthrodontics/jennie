defmodule Jennie.Engine do
  @moduledoc """
  Engine that actions on Jennie tokens
  """

  @empty [%{}, false, nil, [], ""]

  defstruct ~w(binary dynamic)a

  def init() do
    %__MODULE__{
      binary: [],
      dynamic: nil
    }
  end

  # Checks whether current context has a nil state
  defp nil_context?(_, true), do: false
  
  defp nil_context?([{_, value} | _], false) do
    if value in @empty, do: true, else: false
  end

  defp nil_context?([], _), do: false

  def handle_text(state, text, %{scope: scope, ignore_nil: ignore}) do
    %{binary: binary} = state
    if nil_context?(scope, ignore), do: state, else: %{state | binary: [text | binary]}
  end

  def handle_tag(state, expr, %{assigns: assigns, scope: scope, ignore_nil: ignore}) do
    %{binary: binary} = state

    eval =
      scope
      |> Enum.reduce(assigns, fn context, acc ->
        context
        |> to_map()
        |> merge(acc, length(expr) == 1)
      end)
      |> handle_assigns(scope, expr)
      |> clean_up(expr, ignore)
      
    # TODO: reiterate again
    # TODO: This example currently fails: Jennie.render("{{#family}}{{#people}}{{.}}{{/people}}{{/family}}", %{"family" => %{"people" => ["Mum", "Dad", "Son", "Daughter"]}})
  

    %{state | binary: [to_charlist(eval) | binary]}
  end

  defp to_map({_, assign}) when is_map(assign), do: assign

  defp to_map({name, assign}), do: %{name => assign}

  defp merge(map1, map2, false), do: Map.merge(map1, map2)
  defp merge(map1, map2, true), do: Map.merge(map2, map1)

  defp clean_up(eval, expr, true) when eval in @empty, do: "{{#{expr}}}"
  
  defp clean_up(eval, _expr, _), do: eval

  def handle_context(state, expr, %{assigns: assigns, scope: scope, ignore_nil: ignore}) do
    context = handle_assigns(assigns, scope, expr)

    context =
      if is_list(context) and length(context) == 1 do
        List.first(context)
      else
        context
      end
    
    if ignore and context in @empty do
      %{binary: binary} = state
      %{state |
        dynamic: {Enum.join(expr, "."), nil},
        binary: [to_charlist("{{#{expr}}}") | binary]}
    else
      %{state | dynamic: {Enum.join(expr, "."), context}}
    end
  end

  defp handle_assigns(%{"default" => data}, _, ["."]), do: data
  
  defp handle_assigns(assigns, [{_, head} | _rest], ["."]) when is_map(head) do
    Access.get(assigns, ".")
  end

  defp handle_assigns(_assigns, [{_, head} | _rest], ["."]), do: head

  defp handle_assigns(assigns, [{_, parent_scope_assigns} | _rest], expr)
       when is_map(parent_scope_assigns) do
    get_in(assigns, expr) || get_in(parent_scope_assigns, expr)
  end

  defp handle_assigns(assigns, _scope, expr) do
    get_in(assigns, expr)
  end

  def handle_body(state) do
    %{binary: binary} = state

    :erlang.list_to_binary(Enum.reverse(binary))
  end
end
