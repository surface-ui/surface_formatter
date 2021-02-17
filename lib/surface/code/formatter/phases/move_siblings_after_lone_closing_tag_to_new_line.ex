defmodule Surface.Code.Formatter.Phases.MoveSiblingsAfterLoneClosingTagToNewLine do
  @moduledoc """
  """
  @behaviour Surface.Code.Formatter.Phase
  alias Surface.Code.Formatter.Phase

  def run(nodes) do
    nodes
    |> move_siblings_after_lone_closing_tag_to_new_line()
    |> Phase.recurse_on_children(&run/1)
  end

  defp move_siblings_after_lone_closing_tag_to_new_line(nodes, accumulated \\ [])

  defp move_siblings_after_lone_closing_tag_to_new_line(
         [{_, _, children, _} = element, :space | rest],
         accumulated
       ) do
    if Enum.any?(children, &(&1 == :newline)) do
      move_siblings_after_lone_closing_tag_to_new_line(
        rest,
        accumulated ++ [element, :newline]
      )
    else
      move_siblings_after_lone_closing_tag_to_new_line(
        rest,
        accumulated ++ [element, :space]
      )
    end
  end

  defp move_siblings_after_lone_closing_tag_to_new_line([node | rest], accumulated) do
    move_siblings_after_lone_closing_tag_to_new_line(rest, accumulated ++ [node])
  end

  defp move_siblings_after_lone_closing_tag_to_new_line([], accumulated) do
    accumulated
  end
end
