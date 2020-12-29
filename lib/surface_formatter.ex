defmodule SurfaceFormatter do
  @moduledoc """
  Houses code to format Surface code snippets. (In the form of strings.)
  """

  # Use 2 spaces for a tab
  @tab "  "

  # Line length of opening tags before splitting attributes onto their own line
  @max_line_length 80

  @type tag :: String.t()
  @type attribute :: term

  @typedoc "A node output by &Surface.Compiler.Parser.parse/1"
  @type parsed_surface_node ::
          String.t()
          | {:interpolation, String.t(), map}
          | {tag, list(attribute), list(parsed_surface_node), map}

  def format_string!(string) do
    string
    |> String.trim()
    |> Surface.Compiler.Parser.parse()
    |> elem(1)
    |> Enum.flat_map(&parse_whitespace/1)
    |> contextualize_whitespace()
    |> Enum.map(&render/1)
    |> List.flatten()
    # Add final newline
    |> Kernel.++(["\n"])
    |> Enum.join()
  end

  # Deeply traverse parsed Surface nodes, converting string nodes
  # into this format: `{:string, String.t, %{spaces: [String.t, String.t]}}`
  #
  # `spaces` is the whitespace before and after the node. Possible values
  # are `" "` and `""`. `" "` (a space character) means there is whitespace.
  # `""` (empty string) means there isn't.
  defp parse_whitespace(html) when is_binary(html) do
    trimmed_html = String.trim(html)

    if trimmed_html == "" do
      # This is nothing but whitespace. Only include a newline
      # "before" this node (i.e. one \n instead of two) unless there
      # are at least 2 \n's in the string

      newlines =
        html
        |> String.graphemes()
        |> Enum.count(&(&1 == "\n"))

      if newlines < 2 do
        # There's just a bunch of spaces or at most one newline
        [:whitespace]
      else
        # There are at least two newlines; collapse them down to two
        [:whitespace, :whitespace]
      end
    else
      trimmed_html_segments =
        trimmed_html
        # Collapse any string of whitespace that includes a newline down to only
        # the newline
        |> String.replace(~r/\s*\n\s*+/, "\n")
        # Then split into separate logical nodes so the formatter can format
        # the newlines appropriately.
        |> String.split("\n", trim: true)
        |> Enum.intersperse(:whitespace)

      [
        if String.trim_leading(html) != html do
          :whitespace
        end,
        trimmed_html_segments,
        if String.trim_trailing(html) != html do
          :whitespace
        end
      ]
      |> List.flatten()
      # Remove nils
      |> Enum.filter(&Function.identity/1)
    end
  end

  defp parse_whitespace({tag, attributes, children, meta} = node) do
    if render_contents_verbatim?(tag) do
      [node]
    else
      analyzed_children = Enum.flat_map(children, &parse_whitespace/1)
      [{tag, attributes, analyzed_children, meta}]
    end
  end

  # Not a string; do nothing
  defp parse_whitespace(node), do: [node]

  defp contextualize_whitespace(nodes, accumulated \\ [])

  defp contextualize_whitespace([:whitespace], accumulated) do
    accumulated ++ [{:whitespace, :before_closing_tag}]
  end

  defp contextualize_whitespace([node], accumulated) do
    accumulated ++ [contextualize_whitespace_for_single_node(node)]
  end

  defp contextualize_whitespace([:whitespace | rest], accumulated) do
    contextualize_whitespace(
      rest,
      accumulated ++ [{:whitespace, :before_child}]
    )
  end

  defp contextualize_whitespace([node | rest], accumulated) do
    contextualize_whitespace(
      rest,
      accumulated ++ [contextualize_whitespace_for_single_node(node)]
    )
  end

  defp contextualize_whitespace([], accumulated) do
    accumulated
  end

  defp contextualize_whitespace_for_single_node({tag, attributes, children, meta}) do
    {tag, attributes, contextualize_whitespace(children), meta}
  end

  defp contextualize_whitespace_for_single_node(node) do
    node
  end

  @spec render(parsed_surface_node) :: String.t() | nil
  defp render(segment, depth \\ 0)

  defp render({:interpolation, expression, _meta}, _depth) do
    "{{ #{Code.format_string!(expression)} }}"
  end

  defp render({:whitespace, :before_child}, depth) do
    "\n#{String.duplicate(@tab, depth)}"
  end

  defp render({:whitespace, :before_closing_tag}, depth) do
    "\n#{String.duplicate(@tab, max(depth - 1, 0))}"
  end

  defp render(html, _depth) when is_binary(html) do
    html
  end

  defp render({tag, attributes, children, _meta}, depth) do
    self_closing = Enum.empty?(children)
    indentation = String.duplicate(@tab, depth)

    joined_attributes =
      attributes
      |> Enum.map(&render_attribute/1)
      |> case do
        [] ->
          ""

        rendered_attributes ->
          # Prefix attributes string with a space (for after tag name)
          " " <> Enum.join(rendered_attributes, " ")
      end

    opening =
      "<" <>
        tag <>
        joined_attributes <>
        "#{
          if self_closing do
            " /"
          end
        }>"

    # Maybe split opening tag onto multiple lines depending on line length
    opening =
      if String.length(opening) > @max_line_length do
        indented_attributes =
          attributes
          |> Enum.map(&indent(&1, depth + 1))

        [
          "<#{tag}",
          indented_attributes,
          "#{indentation}#{
            if self_closing do
              "/"
            end
          }>"
        ]
        |> List.flatten()
        |> Enum.join("\n")
      else
        opening
      end

    rendered_children =
      if render_contents_verbatim?(tag) do
        [contents] = children
        contents
      else
        children
        |> Enum.map(&render(&1, depth + 1))
      end

    closing = "</#{tag}>"

    if self_closing do
      "#{opening}"
    else
      "#{opening}#{rendered_children}#{closing}"
    end
  end

  defp render_attribute({name, value, _meta}) when is_binary(value),
    do: "#{name}=\"#{String.trim(value)}\""

  # For `true` boolean attributes, simply including the name of the attribute
  # without `=true` is shorthand for `=true`.
  defp render_attribute({name, true, _meta}),
    do: "#{name}"

  defp render_attribute({name, false, _meta}),
    do: "#{name}=false"

  defp render_attribute({name, value, _meta}) when is_number(value),
    do: "#{name}=#{value}"

  defp render_attribute({name, {:attribute_expr, expression, _expr_meta}, _meta})
       when is_binary(expression) do
    # Wrap it in square brackets (and then remove after formatting)
    # to support Surface sugar like this: `{{ foo: "bar" }}` (which is
    # equivalent to `{{ [foo: "bar"] }}`
    formatted_expression =
      "[#{expression}]"
      |> Code.format_string!()
      |> Enum.slice(1..-2)
      |> to_string()

    if String.contains?(formatted_expression, "\n") do
      # Don't add extra space characters around the curly braces because
      # the formatted elixir code has newlines in it; this helps indentation
      # to line up.
      "#{name}={{#{formatted_expression}}}"
    else
      "#{name}={{ #{formatted_expression} }}"
    end
  end

  defp indent(string, depth) do
    # Ensure if they pass in a negative depth that we don't crash
    depth = max(depth, 0)

    indentation = String.duplicate(@tab, depth)

    # This is pretty hacky, but it's an attempt to get
    #   class={{
    #     "foo",
    #     @bar,
    #     baz: true
    #   }}
    # to look right
    string_with_newlines_indented = String.replace(string, "\n", "\n#{indentation}")

    "#{indentation}#{string_with_newlines_indented}"
  end

  # Don't modify contents of macro components or <pre> and <code> tags
  defp render_contents_verbatim?("#" <> _), do: true
  defp render_contents_verbatim?("pre"), do: true
  defp render_contents_verbatim?("code"), do: true
  defp render_contents_verbatim?(tag) when is_binary(tag), do: false
end
