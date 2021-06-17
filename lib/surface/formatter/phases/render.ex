defmodule Surface.Formatter.Phases.Render do
  @moduledoc """
  Render the formatted Surface code after it has run through the other
  transforming phases.
  """

  @behaviour Surface.Formatter.Phase
  alias Surface.Formatter

  def run(nodes, opts) do
    nodes
    |> Enum.map(&render_node(&1, opts))
    |> List.flatten()
    |> Enum.join()
  end

  # Use 2 spaces for a tab
  @tab "  "

  # Line length of opening tags before splitting attributes onto their own line
  @default_line_length 98

  @doc """
  Given a `t:Surface.Formatter.formatter_node/0` node, render it to a string
  for writing back into a file.
  """
  @spec render_node(Formatter.formatter_node(), list(Formatter.option())) :: String.t() | nil
  def render_node(segment, opts)

  def render_node({:expr, expression, _meta}, opts) do
    case Regex.run(~r/^\s*#(.*)$/, expression) do
      nil ->
        formatted =
          expression
          |> String.trim()
          |> Code.format_string!(opts)

        String.replace(
          "{#{formatted}}",
          "\n",
          "\n#{String.duplicate(@tab, opts[:indent])}"
        )

      [_, comment] ->
        # expression is a one-line Elixir comment; convert to a "Surface comment"
        "{!-- #{String.trim(comment)} --}"
    end
  end

  def render_node(:indent, opts) do
    if opts[:indent] >= 0 do
      String.duplicate(@tab, opts[:indent])
    else
      ""
    end
  end

  def render_node(:newline, _opts) do
    # There are multiple newlines in a row; don't add spaces
    # if there aren't going to be other characters after it
    "\n"
  end

  def render_node(:space, _opts) do
    " "
  end

  def render_node({:comment, comment, %{visibility: :public}}, _opts) do
    if String.contains?(comment, "\n") do
      comment
    else
      contents =
        comment
        |> String.replace(~r/^<!--/, "")
        |> String.replace(~r/-->$/, "")
        |> String.trim()

      "<!-- #{contents} -->"
    end
  end

  def render_node({:comment, comment, %{visibility: :private}}, _opts) do
    if String.contains?(comment, "\n") do
      comment
    else
      contents =
        comment
        |> String.replace(~r/^{!--/, "")
        |> String.replace(~r/--}$/, "")
        |> String.trim()

      "{!-- #{contents} --}"
    end
  end

  def render_node(:indent_one_less, opts) do
    # Dedent once; this is before a closing tag, so it should be dedented from children
    render_node(:indent, indent: opts[:indent] - 1)
  end

  def render_node(html, _opts) when is_binary(html) do
    html
  end

  # default block does not get rendered `{#default}`; just children are rendered
  def render_node({:block, :default, [], children, _meta}, opts) do
    next_opts = Keyword.update(opts, :indent, 0, &(&1 + 1))
    Enum.map(children, &render_node(&1, next_opts))
  end

  def render_node({:block, name, expr, children, _meta}, opts) do
    main_block_element = name in ["if", "for", "case"]

    expr =
      case expr do
        [attr] ->
          attr
          |> render_attribute()
          |> String.slice(1..-2)
          |> String.trim()

        [] ->
          nil
      end

    opening =
      "{##{name}#{if expr, do: " "}#{expr}}"
      |> String.replace("\n", "\n" <> String.duplicate(@tab, opts[:indent] + 1))

    next_indent =
      case children do
        [{:block, _, _, _, _} | _] -> 0
        _ -> 1
      end

    next_opts = Keyword.update(opts, :indent, 0, &(&1 + next_indent))
    rendered_children = Enum.map(children, &render_node(&1, next_opts))

    "#{opening}#{rendered_children}#{if main_block_element do
      "{/#{name}}"
    end}"
  end

  def render_node({"#template", [{"slot", slot_name, _} | attributes], children, meta}, opts) do
    render_node({":#{slot_name}", attributes, children, meta}, opts)
  end

  def render_node({tag, attributes, children, _meta}, opts) do
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
        "#{if self_closing do
          " /"
        end}>"

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
          "#{indentation}#{if self_closing do
            "/"
          end}>"
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
          "#{if self_closing and not is_void_element?(tag) do
            " /"
          end}>"
      end

    rendered_children =
      if Formatter.render_contents_verbatim?(tag) do
        Enum.map(children, fn
          html when is_binary(html) ->
            # Render out string portions of <pre>/<code>/<#MacroComponent> children
            # verbatim instead of trimming them.
            html

          child ->
            render_node(child, indent: 0)
        end)
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
    do: "#{name}={false}"

  defp render_attribute({name, value, _meta}) when is_integer(value),
    do: "#{name}={#{Code.format_string!("#{value}")}}"

  defp render_attribute({name, {:attribute_expr, expression, expr_meta}, meta})
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
      [literal] when is_boolean(literal) or is_binary(literal) ->
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
            (is_list(quoted_wrapped_expression) and length(quoted_wrapped_expression) > 1) or
            (is_list(quoted_wrapped_expression) and
               Enum.any?(quoted_wrapped_expression, &is_keyword_item_with_interpolated_key?/1))

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
            |> Code.format_string!(locals_without_parens: [...: 1])
            |> to_string()
          end

        case {name, formatted_expression, expr_meta} do
          {:root, "... " <> expression, _} ->
            "{...#{expression}}"

          {:root, _, _} ->
            "{#{formatted_expression}}"

          {":attrs", _, _} ->
            "{...#{formatted_expression}}"

          {":props", _, _} ->
            "{...#{formatted_expression}}"

          {_, _, %{tagged_expr?: true}} ->
            "{=@#{name}}"

          _ ->
            "#{name}={#{formatted_expression}}"
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

  defp is_keyword_item_with_interpolated_key?(item) do
    case item do
      {{{:., _, [:erlang, :binary_to_atom]}, _, [_, :utf8]}, _} -> true
      _ -> false
    end
  end

  defp is_void_element?(tag) do
    tag in ~w(area base br col command embed hr img input keygen link meta param source track wbr)
  end
end
