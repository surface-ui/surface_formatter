defmodule Surface.Code.Formatter.Phases.CollapseNewlines do
  @moduledoc """
  Prevent more than a single empty line in a row.

  Depends on `TagWhitespace` phase.
  """

  def run(nodes) do
    nodes
    |> Enum.chunk_by(&(&1 == :newline))
    |> Enum.map(fn
      [:newline, :newline | _] -> [:newline, :newline]
      nodes -> nodes
    end)
    |> Enum.flat_map(&Function.identity/1)
    |> Enum.map(fn
      {tag, attributes, children, meta} ->
        {tag, attributes, run(children), meta}

      node ->
        node
    end)
  end
end
