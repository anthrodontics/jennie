defmodule Jennie.Engine do
  @moduledoc """
  Engine that actions on Jennie tokens
  """

  defstruct ~w(binary dynamic null_context_stack)a

  def init(_opts) do
    %__MODULE__{
      binary: [],
      dynamic: [],
      null_context_stack: []
    }
  end

  def pop_context(%{null_context_stack: [_head | tail]} = state),
    do: %{state | null_context_stack: tail}

  def insert_into_context(%{null_context_stack: stack} = state, item),
    do: %{state | null_context_stack: [validate_context(item) | stack]}

  defp context?([pop | _rest]), do: pop
  defp context?([]), do: true

  defp validate_context(item) do
    if item in [%{}, false, nil, [], ""], do: false, else: true
  end

  def handle_text(state, text) do
    check_state!(state)
    %{binary: binary, null_context_stack: stack} = state
    if context?(stack), do: %{state | binary: [text | binary]}, else: state
  end

  def handle_tag(state, expr, %{assigns: assigns, scope: scope}) do
    check_state!(state)
    %{binary: binary, dynamic: dynamic} = state

    eval = handle_assigns(assigns, scope, expr)

    if is_list(eval) or is_map(eval) do
      %{state | dynamic: [eval | dynamic]}
    else
      %{state | binary: [to_charlist(eval) | binary]}
    end
  end

  def handle_context(state, expr, %{assigns: assigns, scope: scope}) do
    check_state!(state)

    eval_context = handle_assigns(assigns, scope, expr)

    insert_into_context(state, eval_context)
  end

  defp handle_assigns(%{"default" => data}, _, ["."]), do: data

  defp handle_assigns(assigns, [head | _rest], ["."]) do
    Access.get(assigns, head)
  end

  defp handle_assigns(assigns, [head | _], [expr | _]) when head == expr,
    do: Access.get(assigns, expr)

  defp handle_assigns(assigns, scope, expr) do
    get_in(assigns, scope ++ expr) || get_in(assigns, expr)
  end

  def handle_body(state) do
    check_state!(state)
    %{binary: binary} = state

    :erlang.list_to_binary(Enum.reverse(binary))
  end

  # Validate that we're passing around THE ENGINE, not something lame
  defp check_state!(%__MODULE__{}), do: :ok

  defp check_state!(state) do
    raise "unexpected Jennie.Engine state: #{inspect(state)}." <>
            "This means either there's a bug or an outdated Jennie Engine"
  end
end
