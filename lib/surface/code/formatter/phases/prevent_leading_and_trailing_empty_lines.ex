defmodule Surface.Code.Formatter.Phases.PreventLeadingAndTrailingEmptyLines do
  @behaviour Surface.Code.Formatter.Phase
  alias Surface.Code.Formatter.Phase

  def run(nodes) do
    nodes
    |> prevent_empty_line_at_beginning()
    |> prevent_empty_line_at_end()
    |> Phase.recurse_on_children(&run/1)
  end

  defp prevent_empty_line_at_beginning([:newline, :newline | rest]), do: [:newline | rest]
  defp prevent_empty_line_at_beginning(nodes), do: nodes

  defp prevent_empty_line_at_end(nodes) do
    case Enum.slice(nodes, -2..-1) do
      [:newline, :newline] -> Enum.slice(nodes, 0..-2)
      _ -> nodes
    end
  end
end
