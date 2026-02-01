defmodule Jennie.Engine do
  @moduledoc """
  Engine that actions on Jennie tokens
  """

  @empty [%{}, false, nil, [], ""]

  defstruct ~w(binary dynamic context_stack cache)a

  def init(_opts) do
    %__MODULE__{
      binary: [],
      dynamic: nil,
      cache: %{}
    }
  end

  def push_context(%{context_stack: context_stack} = state, expr, context) do
    map = %{name: expr, value: context}
    %{state | context_stack: [map | context_stack]}
  end

  def pop_context(%{context_stack: [_head | tail]} = state),
    do: %{state | context_stack: tail}

  # Checks whether current context has a nil state
  defp nil_context?([{_, value} | _]) do
    if value in @empty, do: true, else: false
  end

  defp nil_context?([]), do: false

  def handle_text(state, text, %{scope: scope}) do
    %{binary: binary} = state
    if nil_context?(scope), do: state, else: %{state | binary: [text | binary]}
  end

  def handle_tag(state, expr, %{assigns: assigns, scope: scope}) do
    %{binary: binary} = state

    eval =
      scope
      |> Enum.reduce(assigns, fn context, acc ->
        context
        |> to_map()
        |> merge(acc, length(expr) == 1)
      end)
      |> handle_assigns(scope, expr)

    %{state | binary: [to_charlist(eval) | binary]}

    # if is_list(eval) or is_map(eval) do
    #   %{state | dynamic: [eval | dynamic]}
    # else

    # end
  end

  defp to_map({_, assign}) when is_map(assign), do: assign

  defp to_map({name, assign}), do: %{name => assign}

  defp merge(map1, map2, false), do: Map.merge(map1, map2)
  defp merge(map1, map2, true), do: Map.merge(map2, map1)

  def handle_context(state, expr, %{assigns: assigns, scope: scope}) do
    context = handle_assigns(assigns, scope, expr)

    %{state | dynamic: {Enum.join(expr, "."), context}}
  end

  defp handle_assigns(%{"default" => data}, _, ["."]), do: data

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
