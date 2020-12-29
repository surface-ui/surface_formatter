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
    |> Surface.Compiler.Parser.parse()
    |> elem(1)
    # |> IO.inspect(label: "pre-analyzed")
    # Always remove the trailing newline
    |> Enum.map(&analyze_whitespace/1)
    # |> IO.inspect(label: "analyzed")
    |> Enum.map(&render/1)
    |> List.flatten()
    |> Enum.join()
  end

  # Deeply traverse parsed Surface nodes, converting string nodes
  # into this format: `{:string, String.t, %{spaces: [String.t, String.t]}}`
  #
  # `spaces` is the whitespace before and after the node. Possible values
  # are `" "` and `""`. `" "` (a space character) means there is whitespace.
  # `""` (empty string) means there isn't.
  defp analyze_whitespace(html) when is_binary(html) do
    trimmed_html = String.trim(html)

    if trimmed_html == "" do
      # This is nothing but whitespace. Only include a newline
      # "before" this node (i.e. one \n instead of two) unless there
      # are at least 2 \n's in the string

      newlines =
        html
        |> String.graphemes()
        |> Enum.count(&(&1 == "\n"))

      spaces =
        case newlines do
          0 -> ["", ""]
          1 -> [" ", ""]
          _ -> [" ", " "]
        end

      {:string, "", %{spaces: spaces}}
    else
      {:string, trimmed_html,
       %{
         spaces: [
           if String.trim_leading(html) != html do
             " "
           else
             ""
           end,
           if String.trim_trailing(html) != html do
             " "
           else
             ""
           end
         ]
       }}
    end
  end

  # Don't modify contents of macro components
  defp analyze_whitespace({"#" <> _macro_tag, _attributes, _children, _meta} = node) do
    node
  end

  # Don't modify contents of <pre> or <code> tags
  defp analyze_whitespace({tag, _attributes, _children, _meta} = node)
       when tag in ["pre", "code"] do
    node
  end

  defp analyze_whitespace({tag, attributes, children, meta}) do
    analyzed_children = Enum.map(children, &analyze_whitespace/1)
    {tag, attributes, analyzed_children, meta}
  end

  # Not a string; do nothing
  defp analyze_whitespace(node), do: node

  @spec render(parsed_surface_node) :: String.t() | nil
  defp render(segment, depth \\ 0)

  defp render({:interpolation, expression, _meta} = a, depth) do
    IO.inspect(a, label: "======== onter")
    interpolation = "{{ #{Code.format_string!(expression)} }}"
    indent(interpolation, depth)
  end

  defp render({:string, html, meta}, depth) do
    %{spaces: [whitespace_before, whitespace_after]} = meta

    "#{
      if whitespace_before == " " do
        "\n"
      end
    }#{
      if whitespace_before == " " && html != "" do
        indent(html, depth)
      else
        # Don't indent because there's no leading whitespace,
        # so it's smushed up against the previous node
        html
      end
    }#{
      if whitespace_after == " " do
        "\n"
      end
    }"
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
      if is_macro_tag?(tag) do
        [contents] = children
        contents
      else
        Enum.map(children, &render(&1, depth + 1))
      end
      |> IO.inspect(label: "rendered_children")

    closing = "</#{tag}>"

    if self_closing do
      "#{indentation}#{opening}"
    else
      "#{indentation}#{opening}#{rendered_children}#{indentation}#{closing}"
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

  defp is_macro_tag?("#" <> _), do: true
  defp is_macro_tag?(tag) when is_binary(tag), do: false
end
