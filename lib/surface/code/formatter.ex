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

  @type formatter_node :: surface_node | whitespace

  @doc "Given a list of `t:formatter_node/0`, return a formatted string of Surface code"
  @spec format(list(surface_node), list(option)) :: String.t()
  def format(nodes, opts \\ []) do
    opts = Keyword.put_new(opts, :indent, 0)

    nodes
    |> Enum.flat_map(&tag_whitespace/1)
    |> IO.inspect(label: "============= A")
    |> adjust_whitespace()
    |> IO.inspect(label: "============= B")
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
  @spec tag_whitespace(surface_node) :: [surface_node | :newline | :space]
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
        |> Enum.reject(& &1 == "")

      leading_whitespace ++ lines ++ trailing_whitespace
    end

    # HTML comments are stripped by Surface, and when this happens
    # the surrounding text are counted as separate nodes and not joined.
    # As a result, it's possible to end up with more than 2 consecutive
    # newlines. So here, we check for that and deduplicate them.

    #text
    #|> String.graphemes()
    #|> Enum.count(&(&1 == "\n"))

    # - Return list of text nodes + tagged whitespace
    # - If string is entirely whitespace, boil down to :space or list of :newline
    # - If string is not entirely whitespace, ensure we put leading/trailing newline or space as needed
    # - Prevent more than 2 successive newlines
    # - If this is the first node in a set of children, ensure a newline at the beginning if there's any whitespace at all
    #   (we never do a space, and if there's no whitespace we wouldn't be here)
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
  @spec tag_whitespace_string(String.t | nil) :: list(:space | :newline)
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

  @spec adjust_whitespace([surface_node | whitespace]) :: [surface_node | whitespace]
  def adjust_whitespace([]), do: []
  def adjust_whitespace(nodes) when is_list(nodes) do
    # These nodes are either the root nodes in an ~H sigil or .sface file,
    # or they're all of the children of an HTML element / Surface component.

    # Allow no more than 2 newlines in a row
    nodes =
      nodes
      |> Enum.chunk_by(&(&1 == :newline))
      |> Enum.map(fn
        [:newline, :newline | _] -> [:newline, :newline]
        nodes -> nodes
      end)
      |> Enum.flat_map(&Function.identity/1)

    # Adjust whitespace of contents of child elements
    nodes = Enum.map(nodes, fn
      {tag, attributes, children, meta} ->
        {tag, attributes, adjust_whitespace(children), meta}

      node ->
        node
    end)

    nodes = add_indentation(nodes)

      # FIXME: I think here is where we need to ensure the contents of a tag are
      # either smushed against the tags themselves, or the opening/closing tags
      # are on different lines than the contents. In other words, this isn't
      # allowed: <p> Contents </p>
      # but this is: <p>contents</p>
      # (The former would turn into:)
      # <p>
      #   Contents
      # </p>

      # FIXME: Also, is this where we would inject :indent and :indent_one_less tags
      # before children and closing tags?

      # FIXME: Also, this would probably be a good spot to ensure that
      # child elements are placed on newlines if they contain other elements

      ## Prevent empty line at beginning of children
      #analyzed_children =
        #case analyzed_children do
          #[:newline, :newline | rest] -> [:newline | rest]
          #_ -> analyzed_children
        #end

      ## Prevent empty line at end of children
      #analyzed_children =
        #case Enum.slice(analyzed_children, -2..-1) do
          #[:newline, :newline] -> Enum.slice(analyzed_children, 0..-2)
          #_ -> analyzed_children
        #end
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
    # We've traversed all the children; add indentation for closing tag
    accumulated ++ [:indent_one_less]
  end
  def add_indentation([node | rest], accumulated) do
    add_indentation(rest, accumulated ++ [node])
  end

  ##########################
  ####### OLD CODE TO REMOVE #########
  ##########################

  # HAPPENED ORIGINALLY IN format/1
      #|> parse_for_formatter()
      #|> elem(1)
      #|> parse_whitespace_for_nodes()
      #|> old_transform_whitespace()

    ## Add initial indentation
    #[:indent | parsed]

  # Recurses over nodes, feeding them to parse_whitespace/3 with the
  # node immediately before and after for context.
  def parse_whitespace_for_nodes(nodes, parsed \\ [], last \\ nil)

  def parse_whitespace_for_nodes([], parsed, _last), do: parsed

  def parse_whitespace_for_nodes([node | rest], parsed, last) do
    next = List.first(rest)
    parsed_node = parse_whitespace(node, last, next)
    parse_whitespace_for_nodes(rest, parsed ++ parsed_node, parsed_node)
  end

  @doc """
  Deeply traverse parsed Surface nodes, converting string nodes into a list of
  strings and `:whitespace` atoms.
  """
  @spec parse_whitespace(surface_node, last_node :: surface_node, next_node :: surface_node) ::
          list(surface_node | :space | :newline)
  def parse_whitespace(text, last, next) when is_binary(text) do
    trimmed_text = String.trim(text)

    if trimmed_text == "" do
      parse_only_whitespace(text, last, next)
    else
      trimmed_html_segments =
        trimmed_text
        # Then split into separate logical nodes so the formatter can format
        # the newlines appropriately.
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.intersperse(:newline)

      [
        if leading_whitespace = Regex.run(~r/^\s+/, text) do
          leading_whitespace
          |> List.first()
          |> parse_only_whitespace(last, "")
        end,
        trimmed_html_segments,
        if trailing_whitespace = Regex.run(~r/\s+$/, text) do
          trailing_whitespace
          |> List.first()
          |> parse_only_whitespace(last, next)
        end
      ]
      |> List.flatten()
      |> Enum.reject(&(&1 in [nil, ""]))
    end
  end

  def parse_whitespace({tag, attributes, children, meta} = node, _last, _next) do
    # This is an HTML or Surface element, so the children must be
    # traversed to parse any whitespace.

    if render_contents_verbatim?(tag) do
      [node]
    else
      analyzed_children = parse_whitespace_for_nodes(children)

      # Prevent empty line at beginning of children
      analyzed_children =
        case analyzed_children do
          [:newline, :newline | rest] -> [:newline | rest]
          _ -> analyzed_children
        end

      # Prevent empty line at end of children
      analyzed_children =
        case Enum.slice(analyzed_children, -2..-1) do
          [:newline, :newline] -> Enum.slice(analyzed_children, 0..-2)
          _ -> analyzed_children
        end

      [{tag, attributes, analyzed_children, meta}]
    end
  end

  # Not a string; do nothing
  def parse_whitespace(node, _last, _next), do: [node]

  # Parse a string that only has whitespace, returning [:space]
  # or a list of `:newline` (with at most 2)
  @spec parse_only_whitespace(String.t(), surface_node | nil, surface_node | nil) ::
          list(:space | :newline)
  defp parse_only_whitespace(text, last, next) do
    # This span of text is _only_ whitespace
    newlines =
      text
      |> String.graphemes()
      |> Enum.count(&(&1 == "\n"))

    if force_newline_separator_for?(last) or force_newline_separator_for?(next) do
      # Force at least one newline
      List.duplicate(:newline, max(newlines, 1))
    else
      if newlines > 0 do
        List.duplicate(:newline, newlines)
      else
        [:space]
      end
    end
  end

  defp force_newline_separator_for?({_tag, _attributes, children, _meta}) do
    Enum.any?(children, fn
      {_tag, _attrs, _children, _meta} -> true
      _ -> false
    end)
  end

  defp force_newline_separator_for?(nil), do: true
  defp force_newline_separator_for?(_), do: false

  # This function takes an entire list of sibling nodes (often all the children of a parent node)
  # and recursively iterates over them, transorming the whitespace where appropriate by adding
  # indentation and newlines in certain places based on the context.
  @spec old_transform_whitespace(list(surface_node | :newline | :space)) :: list(formatter_node)
  defp old_transform_whitespace(nodes, accumulated \\ [])

  defp old_transform_whitespace([:newline], accumulated) do
    # This is a final newline before a closing tag; indent but one less than
    # the current level
    accumulated ++ [:newline, :indent_one_less]
  end

  defp old_transform_whitespace([node], accumulated) do
    # This is the final node
    accumulated ++ [transform_whitespace_for_single_node(node)]
  end

  defp old_transform_whitespace([:newline, :newline | rest], accumulated) do
    # 2 newlines in a row; don't put indentation on the empty line
    rest = Enum.drop_while(rest, &(&1 == :newline))

    old_transform_whitespace(
      [:newline | rest],
      accumulated ++ [:newline]
    )
  end

  defp old_transform_whitespace([:newline | rest], accumulated) do
    old_transform_whitespace(
      rest,
      accumulated ++ [:newline, :indent]
    )
  end

  defp old_transform_whitespace([node | rest], accumulated) do
    old_transform_whitespace(
      rest,
      accumulated ++ [transform_whitespace_for_single_node(node)]
    )
  end

  defp old_transform_whitespace([], accumulated) do
    accumulated
  end

  # This function allows us to operate deeply on nested children through recursion
  @spec transform_whitespace_for_single_node(surface_node) :: surface_node
  defp transform_whitespace_for_single_node({tag, attributes, children, meta}) do
    # HTML comments are stripped by Surface, and when this happens
    # the surrounding text are counted as separate nodes and not joined.
    # As a result, it's possible to end up with more than 2 consecutive
    # newlines. So here, we check for that and deduplicate them.
    children =
      children
      |> old_transform_whitespace()
      |> Enum.chunk_by(&(&1 == :newline))
      |> Enum.map(fn
        [:newline, :newline | _] ->
          # Here is where we actually deduplicate. We have a consecutive list of
          # N extra newlines, and we collapse them to at most two.
          [:newline, :newline]

        nodes ->
          nodes
      end)
      |> Enum.flat_map(&Function.identity/1)

    {tag, attributes, children, meta}
  end

  defp transform_whitespace_for_single_node(node) do
    node
  end



  ##############################
  ######### END OLD CODE TO REMOVE
  ############################

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
