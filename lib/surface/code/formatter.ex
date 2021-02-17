defmodule Surface.Code.Formatter do
  @moduledoc """
  Functions for formatting Surface code snippets.
  """

  # Use 2 spaces for a tab
  @tab "  "

  # Line length of opening tags before splitting attributes onto their own line
  @default_line_length 98

  @typedoc """
    - `:line_length` - Maximum line length before wrapping opening tags
    - `:indent` - Starting indentation depth depending on the context of the ~H sigil
  """
  @type option :: {:line_length, integer} | {:indent, integer}

  @typedoc """
  After whitespace is condensed down to `:newline` and `:space`, It's converted
  to this type in a step that looks at the greater context of the whitespace
  and decides where to add indentation (and how much indentation), and where to
  split things onto separate lines.

  - `:newline` adds a `\n` character
  - `:space` adds a ` ` (space) character
  - `:indent` adds spaces at the appropriate indentation amount
  - `:indent_one_less` adds spaces at 1 indentation level removed (used for closing tags)
  """
  @type whitespace ::
          :newline
          | :space
          | :indent
          | :indent_one_less

  @type formatter_node :: Surface.Code.surface_node() | whitespace

  @doc "Given a list of `t:formatter_node/0`, return a formatted string of Surface code"
  @spec format(list(Surface.Code.surface_node()), list(option)) :: String.t()
  def format(nodes, opts \\ []) do
    opts = Keyword.put_new(opts, :indent, 0)

    [:indent | Enum.flat_map(nodes, &tag_whitespace/1)]
    |> adjust_whitespace()
    |> Enum.map(&render(&1, opts))
    |> List.flatten()
    # Add final newline
    |> Kernel.++(["\n"])
    |> Enum.join()
  end

  @doc """
  This function takes a node provided by `Surface.Compiler.Parser.parse/1`
  and converts the leading/trailing whitespace into `t:whitespace/0` nodes.
  """
  @spec tag_whitespace(Surface.Code.surface_node()) :: [
          Surface.Code.surface_node() | :newline | :space
        ]
  def tag_whitespace(text) when is_binary(text) do
    # This is a string/text node; analyze and tag the leading and trailing whitespace

    if String.trim(text) == "" do
      # This is a whitespace-only node; tag the whitespace
      tag_whitespace_string(text)
    else
      # This text contains more than whitespace; analyze and tag the leading
      # and trailing whitespace separately.
      leading_whitespace =
        ~r/^\s+/
        |> single_match!(text)
        |> tag_whitespace_string()

      trailing_whitespace =
        ~r/\s+$/
        |> single_match!(text)
        |> tag_whitespace_string()

      # Get each line of the text node, with whitespace trimmed so we can fix indentation
      lines =
        text
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.intersperse(:newline)
        |> Enum.reject(&(&1 == ""))

      leading_whitespace ++ lines ++ trailing_whitespace
    end

    # HTML comments are stripped by Surface, and when this happens
    # the surrounding text are counted as separate nodes and not joined.
    # As a result, it's possible to end up with more than 2 consecutive
    # newlines. So here, we check for that and deduplicate them.
  end

  def tag_whitespace({tag, attributes, children, meta}) do
    # This is an HTML element or Surface component

    children =
      if render_contents_verbatim?(tag) do
        # Don't tag the contents of this element; it's in a protected class
        # of elements in which the contents are not supposed to be touched
        # (such as <pre>).
        #
        # Note that since we're not tagging the whitespace (i.e. converting
        # sections of the string to :newline and :space atoms), this means
        # we can adjust the whitespace tags later and we're guaranteed not
        # to accidentally modify the contents of these "render verbatim" tags.
        children
      else
        # Recurse into tag_whitespace for all of the children of this element/component
        # so that they get their whitespace tagged as well
        Enum.flat_map(children, &tag_whitespace/1)
      end

    [{tag, attributes, children, meta}]
  end

  def tag_whitespace({:interpolation, _, _} = interpolation), do: [interpolation]

  # Don't modify contents of macro components or <pre> and <code> tags
  defp render_contents_verbatim?("#" <> _), do: true
  defp render_contents_verbatim?("pre"), do: true
  defp render_contents_verbatim?("code"), do: true
  defp render_contents_verbatim?(tag) when is_binary(tag), do: false

  defp single_match!(regex, string) do
    case Regex.run(regex, string) do
      [match] -> match
      nil -> nil
    end
  end

  # Tag a string that only has whitespace, returning [:space] or a list of `:newline`
  @spec tag_whitespace_string(String.t() | nil) :: list(:space | :newline)
  defp tag_whitespace_string(nil), do: []

  defp tag_whitespace_string(text) when is_binary(text) do
    # This span of text is _only_ whitespace
    newlines =
      text
      |> String.graphemes()
      |> Enum.count(&(&1 == "\n"))

    if newlines > 0 do
      List.duplicate(:newline, newlines)
    else
      [:space]
    end
  end

  @spec adjust_whitespace([Surface.Code.surface_node() | whitespace]) :: [
          Surface.Code.surface_node() | whitespace
        ]
  def adjust_whitespace([]), do: []

  def adjust_whitespace(nodes) when is_list(nodes) do
    # These nodes are either the root nodes in an ~H sigil or .sface file,
    # or they're all of the children of an HTML element / Surface component.

    # Allow no more than 2 newlines in a row
    nodes
    |> collapse_newlines()
    |> adjust_whitespace_of_children()
    |> normalize_whitespace_surrounding_elements()
    |> convert_some_spaces_to_newlines_recursive()
    |> convert_spaces_to_newlines_around_edge_element_children()
    |> move_siblings_after_lone_closing_tag_to_new_line()
    |> prevent_empty_line_at_beginning()
    |> prevent_empty_line_at_end()
    |> add_indentation()
  end

  defp collapse_newlines(nodes) do
    nodes
    |> Enum.chunk_by(&(&1 == :newline))
    |> Enum.map(fn
      [:newline, :newline | _] -> [:newline, :newline]
      nodes -> nodes
    end)
    |> Enum.flat_map(&Function.identity/1)
  end

  defp adjust_whitespace_of_children(nodes) do
    Enum.map(nodes, fn
      {tag, attributes, children, meta} ->
        {tag, attributes, adjust_whitespace(children), meta}

      node ->
        node
    end)
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
    accumulated
  end

  defp convert_spaces_to_newlines_around_edge_element_children(nodes) do
    # If there is a space before the first child, and it's an element, convert it to a newline
    nodes =
      case nodes do
        [:space, element | rest] ->
          [:newline, element | rest]

        _ ->
          nodes
      end

    # If there is a space before the first child, and it's an element, convert it to a newline
    case Enum.reverse(nodes) do
      [:space, element | _rest] ->
        Enum.slice(nodes, 0..-3) ++ [element, :newline]

      _ ->
        nodes
    end
  end

  defp convert_some_spaces_to_newlines_recursive(nodes, accumulated \\ [])

  defp convert_some_spaces_to_newlines_recursive(
         [:space, {_, _, children, _} = element, :space | rest],
         accumulated
       ) do
    whitespace =
      if Enum.any?(children, &Surface.Code.is_element?/1) do
        :newline
      else
        :space
      end

    convert_some_spaces_to_newlines_recursive(
      rest,
      accumulated ++ [whitespace, element, whitespace]
    )
  end

  defp convert_some_spaces_to_newlines_recursive(
         [{_, _, children, _} = element, :space | rest],
         accumulated
       ) do
    whitespace =
      if Enum.any?(children, &Surface.Code.is_element?/1) do
        :newline
      else
        :space
      end

    convert_some_spaces_to_newlines_recursive(
      rest,
      accumulated ++ [element, whitespace]
    )
  end

  defp convert_some_spaces_to_newlines_recursive([node | rest], accumulated) do
    convert_some_spaces_to_newlines_recursive(rest, accumulated ++ [node])
  end

  defp convert_some_spaces_to_newlines_recursive([], accumulated) do
    accumulated
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

  defp prevent_empty_line_at_beginning([:newline, :newline | rest]), do: [:newline | rest]
  defp prevent_empty_line_at_beginning(nodes), do: nodes

  defp prevent_empty_line_at_end(nodes) do
    case Enum.slice(nodes, -2..-1) do
      [:newline, :newline] -> Enum.slice(nodes, 0..-2)
      _ -> nodes
    end
  end

  # By the time add_indentation is called, :newline elements have
  # been reduced to at most 2 in a row.
  def add_indentation(nodes, accumulated \\ [])

  def add_indentation([:newline, :newline | rest], accumulated) do
    # Two newlines in a row; don't add indentation on the empty line
    add_indentation(rest, accumulated ++ [:newline, :newline, :indent])
  end

  def add_indentation([:newline], accumulated) do
    # The last child is a newline; add indentation for closing tag
    accumulated ++ [:newline, :indent_one_less]
  end

  def add_indentation([:newline | rest], accumulated) do
    # Indent before the next child
    add_indentation(rest, accumulated ++ [:newline, :indent])
  end

  def add_indentation([], accumulated) do
    # We've traversed all the children; no need to add indentation for closing tag
    # because that's handled in the clause where :newline is the last node
    accumulated
  end

  def add_indentation([node | rest], accumulated) do
    add_indentation(rest, accumulated ++ [node])
  end

  # Take a formatter_node and return a formatted string
  @spec render(formatter_node, list(option)) :: String.t() | nil
  defp render(segment, opts)

  defp render({:interpolation, expression, _meta}, opts) do
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

  defp render(:indent, opts) do
    if opts[:indent] >= 0 do
      String.duplicate(@tab, opts[:indent])
    else
      ""
    end
  end

  defp render(:newline, _opts) do
    # There are multiple newlines in a row; don't add spaces
    # if there aren't going to be other characters after it
    "\n"
  end

  defp render(:space, _opts) do
    " "
  end

  defp render(:indent_one_less, opts) do
    # Dedent once; this is before a closing tag, so it should be dedented from children
    render(:indent, indent: opts[:indent] - 1)
  end

  defp render(html, _opts) when is_binary(html) do
    html
  end

  defp render({tag, attributes, children, _meta}, opts) do
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
        Enum.map(children, fn
          html when is_binary(html) ->
            # Render out string portions of <pre>/<code>/<#MacroComponent> children
            # verbatim instead of trimming them.
            html

          child ->
            render(child, indent: 0)
        end)
      else
        next_opts = Keyword.update(opts, :indent, 0, &(&1 + 1))

        Enum.map(children, &render(&1, next_opts))
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
    # `{:do_not_indent_newlines, formatted}` we instruct `render/1`
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
end
