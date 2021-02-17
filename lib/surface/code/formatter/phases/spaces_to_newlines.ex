defmodule Surface.Code.Formatter.Phases.SpacesToNewlines do
  @moduledoc """
  In a variety of scenarios, converts :space nodes to :newline nodes.
  """

  @behaviour Surface.Code.Formatter.Phase
  alias Surface.Code.Formatter.Phase

  def run(nodes) do
    nodes
    |> normalize_whitespace_surrounding_elements()
    |> ensure_newlines_surrounding_elements_with_element_children()
    |> convert_spaces_to_newlines_around_edge_children()
    |> move_siblings_after_lone_closing_tag_to_new_line()
  end

  # Ensures that if there's an HTML element / Surface component with
  # a newline before it, there will be a newline after as well.
  defp normalize_whitespace_surrounding_elements(nodes, accumulated \\ [])

  defp normalize_whitespace_surrounding_elements(
         [:newline, {_, _, _, _} = element, :space | rest],
         accumulated
       ) do
    normalize_whitespace_surrounding_elements(
      rest,
      accumulated ++ [:newline, element, :newline]
    )
  end

  defp normalize_whitespace_surrounding_elements([node | rest], accumulated) do
    normalize_whitespace_surrounding_elements(rest, accumulated ++ [node])
  end

  defp normalize_whitespace_surrounding_elements([], accumulated) do
    Phase.recurse_on_children(
      accumulated,
      &normalize_whitespace_surrounding_elements/1
    )
  end

  # If an element has an element as a child, ensure it's surrounded by newlines, not spaces
  defp ensure_newlines_surrounding_elements_with_element_children(nodes, accumulated \\ [])

  defp ensure_newlines_surrounding_elements_with_element_children(
         [:space, {_, _, children, _} = element, :space | rest],
         accumulated
       ) do
    whitespace =
      if Enum.any?(children, &Surface.Code.is_element?/1) do
        :newline
      else
        :space
      end

    ensure_newlines_surrounding_elements_with_element_children(
      rest,
      accumulated ++ [whitespace, element, whitespace]
    )
  end

  defp ensure_newlines_surrounding_elements_with_element_children(
         [{_, _, children, _} = element, :space | rest],
         accumulated
       ) do
    whitespace =
      if Enum.any?(children, &Surface.Code.is_element?/1) do
        :newline
      else
        :space
      end

    ensure_newlines_surrounding_elements_with_element_children(
      rest,
      accumulated ++ [element, whitespace]
    )
  end

  defp ensure_newlines_surrounding_elements_with_element_children([node | rest], accumulated) do
    ensure_newlines_surrounding_elements_with_element_children(rest, accumulated ++ [node])
  end

  defp ensure_newlines_surrounding_elements_with_element_children([], accumulated) do
    Phase.recurse_on_children(
      accumulated,
      &ensure_newlines_surrounding_elements_with_element_children/1
    )
  end

  # If there is a space before the first child / after the last, convert it to a newline
  defp convert_spaces_to_newlines_around_edge_children(nodes) do
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
        [:space, _element | _rest] ->
          Enum.slice(nodes, 0..-2) ++ [:newline]

        _ ->
          nodes
      end

    nodes
    |> Phase.recurse_on_children(&convert_spaces_to_newlines_around_edge_children/1)
  end

  # Basically makes sure that this
  #
  # <p>
  #   Foo
  # </p> <p>Hello</p>
  #
  # turns into this
  #
  # <p>
  #   Foo
  # </p>
  # <p>Hello</p>
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
    Phase.recurse_on_children(accumulated, &move_siblings_after_lone_closing_tag_to_new_line/1)
  end
end
