defmodule Jennie.Engine do
  @moduledoc """
  Behaviour for output accumulation, plus the default iolist implementation.
  """

  @type acc :: term()

  @callback init() :: acc
  @callback handle_text(acc, iodata()) :: acc
  @callback handle_body(acc) :: binary()

  @behaviour __MODULE__

  @impl true
  def init, do: []

  @impl true
  # Fragments are prepended (reverse order) and reversed once in handle_body.
  def handle_text(acc, iodata), do: [iodata | acc]

  @impl true
  def handle_body(acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()
end
