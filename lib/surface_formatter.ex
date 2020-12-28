defmodule SurfaceFormatter do
  @moduledoc """
  Houses code to format Surface code snippets. (In the form of strings.)
  """

  # Use 2 spaces for a tab
  @tab "  "

  # Line length of opening tags before splitting attributes onto their own line
  @max_line_length 80

  @typedoc "A node output by &Surface.Compiler.Parser.parse/1"
  @type parsed_surface_node :: term

  @typedoc "An HTML/Surface tag"
  @type tag :: String.t()

  @typedoc """
  An HTML/Surface attribute string, such as `class="container"`,
  `width=6`, or `items={{ @cart_items }}`
  """
  @type attribute :: String.t()

  @typedoc "Children of an HTML element"
  @type children :: list(code_segment)

  @typedoc "A segment of HTML that can be rendered given a tab level"
  @type code_segment :: String.t() | {tag, list(attribute), children}

  def format_string!(string) do
    string
    |> Surface.Compiler.Parser.parse()
    |> elem(1)
    |> Enum.map(&render/1)
    |> List.flatten()
    |> Enum.join("\n")
  end

  @spec render(parsed_surface_node) :: String.t() | nil
  defp render(segment, depth \\ 0)

  defp render({:interpolation, expression, _meta}, depth) do
    "{{ #{Code.format_string!(expression)} }}"
    |> indent(depth)
  end

  defp render("", _depth) do
    nil
  end

  defp render("\n", _depth) do
    # When this empty string is joined to surrounding code, it will end
    # up putting a newline in between, retaining whitespace from the user.
    ""
  end

  defp render(html, depth) when is_binary(html) do
    case String.trim(html) do
      "" ->
        # This string only contained whitespace, so make sure we format
        # this as a newline as long as the string contains at least 2 newlines
        newlines =
          html
          |> String.graphemes()
          |> Enum.count(& &1 == "\n")

        if newlines > 1 do
          "\n"
        else
          ""
        end

      trimmed ->
        # FIXME: I think this is a problem branch; when we trimmed above,
        # we lost vital information about whether nodes were separated
        # by whitespace or not.
        indent(trimmed, depth)
    end
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

    opening = "<" <> tag <> joined_attributes <> "#{if self_closing do " /" end}>"

    opening =
      if String.length(opening) > @max_line_length do
        indented_attributes =
          attributes
          |> Enum.map(&indent(&1, depth + 1))

        [
          "<#{tag}",
          indented_attributes,
          "#{indentation}#{if self_closing do "/" end}>"
        ]
        |> List.flatten()
        |> Enum.join("\n")
      else
        opening
      end

    rendered_children = if is_macro_tag?(tag) do
      [contents] = children
      contents
    else
      children
      |> Enum.map(fn child ->
        render(child, depth + 1)
      end)
      |> List.flatten()
      # Remove nils
      |> Enum.filter(&Function.identity/1)
      |> Enum.join()
    end

    closing = "</#{tag}>"

    if self_closing do
      "#{indentation}#{opening}"
    else
      "#{indentation}#{opening}\n#{rendered_children}\n#{indentation}#{closing}"
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

  defp render_attribute({name, {:attribute_expr, expression, _expr_meta}, _meta}) when is_binary(expression) do
    formatted_expression =
      # Wrap it in square brackets (and then remove after formatting)
      # to support Surface sugar like this: `{{ foo: "bar" }}` (which is
      # equivalent to `{{ [foo: "bar"] }}`
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

  defp is_macro_tag?("#" <> _), do: true
  defp is_macro_tag?(tag) when is_binary(tag), do: false
end
