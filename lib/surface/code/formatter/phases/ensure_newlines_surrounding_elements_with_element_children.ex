defmodule Surface.Code.Formatter.Phases.EnsureNewlinesSurroundingElementsWithElementChildren do
  @moduledoc """
  Ensures that elements that have other elements as children are surrounded
  by newlines instead of spaces.
  """

  @behaviour Surface.Code.Formatter.Phase
  alias Surface.Code.Formatter.Phase

  def run(nodes) do
    nodes
    |> format_nodes()
    |> Phase.recurse_on_children(&run/1)
  end

  defp format_nodes(nodes, accumulated \\ [])

  defp format_nodes(
         [:space, {_, _, children, _} = element, :space | rest],
         accumulated
       ) do
    whitespace =
      if Enum.any?(children, &Surface.Code.is_element?/1) do
        :newline
      else
        :space
      end

    format_nodes(
      rest,
      accumulated ++ [whitespace, element, whitespace]
    )
  end

  defp format_nodes(
         [{_, _, children, _} = element, :space | rest],
         accumulated
       ) do
    whitespace =
      if Enum.any?(children, &Surface.Code.is_element?/1) do
        :newline
      else
        :space
      end

    format_nodes(
      rest,
      accumulated ++ [element, whitespace]
    )
  end

  defp format_nodes([node | rest], accumulated) do
    format_nodes(rest, accumulated ++ [node])
  end

  defp format_nodes([], accumulated) do
    accumulated
  end
end
