defmodule Surface.Code.Formatter.Phases.ConvertSpacesToNewlinesAroundEdgeElementChildren do
  @moduledoc """
  Ensure that if the
  """

  @behaviour Surface.Code.Formatter.Phase
  alias Surface.Code.Formatter.Phase

  def run(nodes) do
    # If there is a space before the first child, and it's an element, convert it to a newline
    nodes =
      case nodes do
        [:space, element | rest] ->
          [:newline, element | rest]

        _ ->
          nodes
      end

    # If there is a space before the first child, and it's an element, convert it to a newline
    nodes =
      case Enum.reverse(nodes) do
        [:space, element | _rest] ->
          Enum.slice(nodes, 0..-3) ++ [element, :newline]

        _ ->
          nodes
      end

    Phase.recurse_on_children(nodes, &run/1)
  end
end
