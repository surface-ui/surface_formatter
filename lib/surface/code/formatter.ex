defmodule Surface.Code.Formatter do
  @moduledoc """
  Functions for formatting Surface code snippets.
  """

  # Use 2 spaces for a tab
  @tab "  "

  # Line length of opening tags before splitting attributes onto their own line
  @default_line_length 98

  @typedoc """
  The name of an HTML/Surface tag, such as `div`, `ListItem`, or `#Markdown`
  """
  @type tag :: String.t()

  @typedoc "The value of a parsed HTML/Component attribute"
  @type attribute_value ::
          integer
          | boolean
          | String.t()
          | {:attribute_expr, interpolated_expression :: String.t(), term}
          | [String.t()]

  @typedoc "A parsed HTML/Component attribute name and value"
  @type attribute :: {name :: String.t(), attribute_value, term}

  @typedoc "A node output by `Surface.Compiler.Parser.parse/1`"
  @type surface_node ::
          String.t()
          | {:interpolation, String.t(), map}
          | {tag, list(attribute), list(surface_node), map}

  @typedoc """
  Context of a section of whitespace. This allows the formatter to decide things
  such as how much indentation to provide after a newline.
  """
  @type whitespace_context :: :before_child | :before_closing_tag | :before_whitespace | :indent

  @typedoc """
  A node output by `parse/1`. Simply a transformation of the output of
  `parse/1`, with contextualized whitespace nodes parsed out of the string
  nodes.
  """
  @type formatter_node :: surface_node | {:whitespace, whitespace_context}

  @typedoc """
    - `:line_length` - Maximum line length before wrapping opening tags
    - `:indent` - Starting indentation depth depending on the context of the ~H sigil
  """
  @type option :: {:line_length, integer} | {:indent, integer}

  @doc """
  Given a string of Surface code, return a list of surface nodes including special
  whitespace nodes that enable formatting.
  """
  @spec parse(String.t()) :: list(formatter_node)
  def parse(string) do
    {:ok, parsed_by_surface} =
      string
      |> String.trim()
      |> Surface.Compiler.Parser.parse()

    parsed =
      parsed_by_surface
      |> Enum.flat_map(&parse_whitespace/1)
      |> contextualize_whitespace()

    # Add initial indentation
    [{:whitespace, :indent} | parsed]
  end

  @doc "Given a list of `t:formatter_node/0`, return a formatted string of Surface code"
  @spec format(list(formatter_node), list(option)) :: String.t()
  def format(nodes, opts \\ []) do
    opts = Keyword.put_new(opts, :indent, 0)

    nodes
    |> Enum.map(&render_node(&1, opts))
    |> List.flatten()
    # Add final newline
    |> Kernel.++(["\n"])
    |> Enum.join()
  end

  @doc """
  Deeply traverse parsed Surface nodes, converting string nodes into a list of
  strings and `:whitespace` atoms.
  """
  @spec parse_whitespace(surface_node) :: list(surface_node | :whitespace)
  def parse_whitespace(html) when is_binary(html) do
    trimmed_html = String.trim(html)

    if trimmed_html == "" do
      collapse_whitespace(html)
    else
      trimmed_html_segments =
        trimmed_html
        # Collapse any string of whitespace that includes a newline down to only
        # the newline
        |> String.replace(~r/\s*\n\s*+/, fn whitespace ->
          whitespace
          |> collapse_whitespace()
          |> case do
            [:whitespace] -> "\n"
            [:whitespace, :whitespace] -> "\n\n"
          end
        end)
        # Then split into separate logical nodes so the formatter can format
        # the newlines appropriately.
        |> String.split("\n")
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
      |> Enum.reject(&(&1 in [nil, ""]))
    end
  end

  def parse_whitespace({tag, attributes, children, meta} = node) do
    if render_contents_verbatim?(tag) do
      [node]
    else
      analyzed_children = Enum.flat_map(children, &parse_whitespace/1)

      # Prevent empty line at beginning of children
      analyzed_children =
        case analyzed_children do
          [:whitespace, :whitespace | rest] -> [:whitespace | rest]
          _ -> analyzed_children
        end

      # Prevent empty line at end of children
      analyzed_children =
        case Enum.slice(analyzed_children, -2..-1) do
          [:whitespace, :whitespace] -> Enum.slice(analyzed_children, 0..-2)
          _ -> analyzed_children
        end

      [{tag, attributes, analyzed_children, meta}]
    end
  end

  # Not a string; do nothing
  def parse_whitespace(node), do: [node]

  # Given a string only containing whitespace, return [:whitespace, :whitespace] if
  # there is more than one \n, otherwise [:whitespace].
  #
  # This helps us defer to the existing code formatting and retain (at most one)
  # extra newline in between nodes.
  @spec collapse_whitespace(String.t()) :: list(:whitespace)
  defp collapse_whitespace(whitespace_string) when is_binary(whitespace_string) do
    newlines =
      whitespace_string
      |> String.graphemes()
      |> Enum.count(&(&1 == "\n"))

    if newlines < 2 do
      # There's just a bunch of spaces or at most one newline
      [:whitespace]
    else
      # There are at least two newlines; collapse them down to two
      [:whitespace, :whitespace]
    end
  end

  @spec contextualize_whitespace(list(surface_node | :whitespace)) :: list(formatter_node)
  defp contextualize_whitespace(nodes, accumulated \\ [])

  defp contextualize_whitespace([:whitespace], accumulated) do
    accumulated ++ [{:whitespace, :before_closing_tag}]
  end

  defp contextualize_whitespace([node], accumulated) do
    accumulated ++ [contextualize_whitespace_for_single_node(node)]
  end

  defp contextualize_whitespace([:whitespace, :whitespace | rest], accumulated) do
    # 2 newlines in a row
    contextualize_whitespace(
      [:whitespace | rest],
      accumulated ++ [{:whitespace, :before_whitespace}]
    )
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

  # This function allows us to operate deeply on nested children through recursion
  @spec contextualize_whitespace_for_single_node(surface_node) :: surface_node
  defp contextualize_whitespace_for_single_node({tag, attributes, children, meta}) do
    # HTML comments are stripped by Surface, and when this happens
    # the surrounding text are counted as separate nodes and not joined.
    # As a result, it's possible to end up with more than 2 consecutive
    # newlines. So here, we check for that and deduplicate them.
    children =
      children
      |> contextualize_whitespace()
      |> Enum.chunk_by(&(&1 == {:whitespace, :before_whitespace}))
      |> Enum.map(fn
        [{:whitespace, :before_whitespace} | _] ->
          # Here is where we actually deduplicate. We have a consecutive list of
          # N extra newlines, and we collapse them to one.
          [{:whitespace, :before_whitespace}]

        nodes ->
          nodes
      end)
      |> Enum.flat_map(&Function.identity/1)

    {tag, attributes, children, meta}
  end

  defp contextualize_whitespace_for_single_node(node) do
    node
  end

  # Take a formatter_node and return a formatted string
  @spec render_node(formatter_node, list(option)) :: String.t() | nil
  defp render_node(segment, opts)

  defp render_node({:interpolation, expression, _meta}, opts) do
    formatted =
      expression
      |> String.trim()
      |> Code.format_string!(opts)

    String.replace(
      "{{ #{formatted} }}",
      "\n",
      "\n#{String.duplicate(@tab, opts[:indent])}"
    )
  end

  defp render_node({:whitespace, :indent}, opts) do
    String.duplicate(@tab, opts[:indent])
  end

  defp render_node({:whitespace, :before_whitespace}, _opts) do
    # There are multiple newlines in a row; don't add spaces
    # if there aren't going to be other characters after it
    "\n"
  end

  defp render_node({:whitespace, :before_child}, opts) do
    "\n#{String.duplicate(@tab, opts[:indent])}"
  end

  defp render_node({:whitespace, :before_closing_tag}, opts) do
    "\n#{String.duplicate(@tab, max(opts[:indent] - 1, 0))}"
  end

  defp render_node(html, _opts) when is_binary(html) do
    html
  end

  defp render_node({tag, attributes, children, _meta}, opts) do
    self_closing = Enum.empty?(children)
    indentation = String.duplicate(@tab, opts[:indent])
    rendered_attributes = Enum.map(attributes, &render_attribute/1)

    attributes_on_same_line =
      case rendered_attributes do
        [] ->
          ""

        rendered_attributes ->
          # Prefix attributes string with a space (for after tag name)
          joined_attributes =
            rendered_attributes
            |> Enum.map(fn
              {:do_not_indent_newlines, attr} -> attr
              attr -> attr
            end)
            |> Enum.join(" ")

          " " <> joined_attributes
      end

    opening_on_one_line =
      "<" <>
        tag <>
        attributes_on_same_line <>
        "#{
          if self_closing do
            " /"
          end
        }>"

    line_length = opts[:line_length] || @default_line_length
    attributes_contain_newline = String.contains?(attributes_on_same_line, "\n")
    line_length_exceeded = String.length(opening_on_one_line) > line_length

    put_attributes_on_separate_lines =
      length(attributes) > 1 and (attributes_contain_newline or line_length_exceeded)

    # Maybe split opening tag onto multiple lines depending on line length
    opening =
      if put_attributes_on_separate_lines do
        attr_indentation = String.duplicate(@tab, opts[:indent] + 1)

        indented_attributes =
          Enum.map(
            rendered_attributes,
            fn
              {:do_not_indent_newlines, attr} ->
                "#{attr_indentation}#{attr}"

              attr ->
                # This is pretty hacky, but it's an attempt to get things like
                #   class={{
                #     "foo",
                #     @bar,
                #     baz: true
                #   }}
                # to look right
                with_newlines_indented = String.replace(attr, "\n", "\n#{attr_indentation}")

                "#{attr_indentation}#{with_newlines_indented}"
            end
          )

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
        # We're not splitting attributes onto their own newlines,
        # but it's possible that an attribute has a newline in it
        # (for interpolated maps/lists) so ensure those lines are indented.
        # We're rebuilding the tag from scratch so we can respect
        # :do_not_indent_newlines attributes.
        attr_indentation = String.duplicate(@tab, opts[:indent])

        attributes =
          case rendered_attributes do
            [] ->
              ""

            _ ->
              joined_attributes =
                rendered_attributes
                |> Enum.map(fn
                  {:do_not_indent_newlines, attr} -> attr
                  attr -> String.replace(attr, "\n", "\n#{attr_indentation}")
                end)
                |> Enum.join(" ")

              # Prefix attributes string with a space (for after tag name)
              " " <> joined_attributes
          end

        "<" <>
          tag <>
          attributes <>
          "#{
            if self_closing do
              " /"
            end
          }>"
      end

    rendered_children =
      if render_contents_verbatim?(tag) do
        [contents] = children
        contents
      else
        next_opts = Keyword.update(opts, :indent, 0, &(&1 + 1))

        Enum.map(children, &render_node(&1, next_opts))
      end

    if self_closing do
      "#{opening}"
    else
      "#{opening}#{rendered_children}</#{tag}>"
    end
  end

  @spec render_attribute({String.t(), term, map}) ::
          String.t() | {:do_not_indent_newlines, String.t()}
  defp render_attribute({name, value, _meta}) when is_binary(value) do
    # This is a string, and it might contain newlines. By returning
    # `{:do_not_indent_newlines, formatted}` we instruct `render_node/1`
    # to leave newlines alone instead of adding extra tabs at the
    # beginning of the line.
    #
    # Before this behavior, the extra lines in the `bar` attribute below
    # would be further indented each time the formatter was run.
    #
    # <Component foo=false bar="a
    #   b
    #   c"
    # />
    {:do_not_indent_newlines, "#{name}=\"#{String.trim(value)}\""}
  end

  # For `true` boolean attributes, simply including the name of the attribute
  # without `=true` is shorthand for `=true`.
  defp render_attribute({name, true, _meta}),
    do: "#{name}"

  defp render_attribute({name, false, _meta}),
    do: "#{name}=false"

  defp render_attribute({name, value, _meta}) when is_integer(value),
    do: "#{name}=#{Code.format_string!("#{value}")}"

  defp render_attribute({name, {:attribute_expr, expression, _expr_meta}, meta})
       when is_binary(expression) do
    # Wrap it in square brackets (and then remove after formatting)
    # to support Surface sugar like this: `{{ foo: "bar" }}` (which is
    # equivalent to `{{ [foo: "bar"] }}`
    quoted_wrapped_expression =
      try do
        Code.string_to_quoted!("[#{expression}]")
      rescue
        _exception ->
          # With some expressions such as function calls without parentheses
          # (e.g. `Enum.map @items, & &1.foo`) wrapping in square brackets will
          # emit invalid syntax, so we must catch that here
          Code.string_to_quoted!(expression)
      end

    case quoted_wrapped_expression do
      [literal] when is_boolean(literal) or is_binary(literal) or is_integer(literal) ->
        # The code is a literal value in Surface brackets, e.g. {{ 12345 }} or {{ true }},
        # that can exclude the brackets, so render it without the brackets
        render_attribute({name, literal, meta})

      _ ->
        # This is a somewhat hacky way of checking if the contents are something like:
        #
        #   foo={{ "bar", @baz, :qux }}
        #   foo={{ "bar", baz: true }}
        #
        # which is valid Surface syntax; an outer list wrapping the entire expression is implied.
        has_invisible_brackets =
          Keyword.keyword?(quoted_wrapped_expression) or
            (is_list(quoted_wrapped_expression) and length(quoted_wrapped_expression) > 1)

        formatted_expression =
          if has_invisible_brackets do
            # Handle keyword lists, which will be stripped of the outer brackets
            # per surface syntax sugar

            "[#{expression}]"
            |> Code.format_string!()
            |> Enum.slice(1..-2)
            |> to_string()
          else
            expression
            |> Code.format_string!()
            |> to_string()
          end

        if String.contains?(formatted_expression, "\n") do
          # Don't add extra space characters around the curly braces because
          # the formatted elixir code has newlines in it; this helps indentation
          # to line up.
          "#{name}={{#{formatted_expression}}}"
        else
          "#{name}={{ #{formatted_expression} }}"
        end
    end
  end

  defp render_attribute({name, strings_and_expressions, _meta})
       when is_list(strings_and_expressions) do
    formatted_expressions =
      strings_and_expressions
      |> Enum.map(fn
        string when is_binary(string) ->
          string

        {:attribute_expr, expression, _expr_meta} ->
          formatted_expression =
            expression
            |> Code.format_string!()
            |> to_string()

          "{{ #{formatted_expression} }}"
      end)
      |> Enum.join()

    "#{name}=\"#{formatted_expressions}\""
  end

  # Don't modify contents of macro components or <pre> and <code> tags
  defp render_contents_verbatim?("#" <> _), do: true
  defp render_contents_verbatim?("pre"), do: true
  defp render_contents_verbatim?("code"), do: true
  defp render_contents_verbatim?(tag) when is_binary(tag), do: false
end
