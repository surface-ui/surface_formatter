defmodule Surface.Code.Formatter.Phases.NormalizeWhitespaceSurroundingElements do
  @moduledoc """
  Inspects all text nodes and "tags" leading and trailing whitespace
  by converting it into a `:space` atom or a list of `:newline` atoms.
  """

  @behaviour Surface.Code.Formatter.Phase
  alias Surface.Code.Formatter.Phase

  def run(nodes) do
    nodes
    |> normalize_whitespace_surrounding_elements()
    |> Phase.recurse_on_children(&run/1)
  end

  defp normalize_whitespace_surrounding_elements(nodes, accumulated \\ [])

  defp normalize_whitespace_surrounding_elements(
         [:newline, {_, _, _, _} = element, :space | rest],
         accumulated
       ) do
    # Ensures that if there's an HTML element / Surface component with
    # a newline before it, there will be a newline after as well.
    normalize_whitespace_surrounding_elements(
      rest,
      accumulated ++ [:newline, element, :newline]
    )
  end

  defp normalize_whitespace_surrounding_elements([node | rest], accumulated) do
    normalize_whitespace_surrounding_elements(rest, accumulated ++ [node])
  end

  defp normalize_whitespace_surrounding_elements([], accumulated) do
    Enum.map(accumulated, fn
      {tag, attributes, children, meta} ->
        {tag, attributes, normalize_whitespace_surrounding_elements(children), meta}

      node ->
        node
    end)
  end
end
