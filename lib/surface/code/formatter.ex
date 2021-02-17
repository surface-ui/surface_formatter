defmodule Surface.Code.Formatter do
  @moduledoc """
  Functions for formatting Surface code snippets.
  """

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

  alias Surface.Code.Formatter.Render
  alias Surface.Code.Formatter.Phases.{
    CollapseNewlines,
    TagWhitespace,
    SurroundingWhitespace,
    NormalizeWhitespaceSurroundingElements,
    EnsureNewlinesSurroundingElementsWithElementChildren,
    ConvertSpacesToNewlinesAroundEdgeElementChildren,
    MoveSiblingsAfterLoneClosingTagToNewLine,
    PreventLeadingAndTrailingEmptyLines,
    Indent
  }

  @doc "Given a list of `t:formatter_node/0`, return a formatted string of Surface code"
  @spec format(list(Surface.Code.surface_node()), list(option)) :: String.t()
  def format(nodes, opts \\ []) do
    opts = Keyword.put_new(opts, :indent, 0)

    nodes
    |> run_phases()
    |> Enum.map(&Render.node(&1, opts))
    |> List.flatten()
    # Add final newline
    |> Kernel.++(["\n"])
    |> Enum.join()
  end

  @spec run_phases([Surface.Code.surface_node()]) :: [formatter_node]
  defp run_phases(nodes) do
    Enum.reduce(phases(), nodes, fn phase, nodes ->
      phase.run(nodes)
    end)
  end

  defp phases do
    [
      TagWhitespace,
      SurroundingWhitespace,
      CollapseNewlines,
      NormalizeWhitespaceSurroundingElements,
      EnsureNewlinesSurroundingElementsWithElementChildren,
      ConvertSpacesToNewlinesAroundEdgeElementChildren,
      MoveSiblingsAfterLoneClosingTagToNewLine,
      PreventLeadingAndTrailingEmptyLines,
      Indent
    ]
  end

  @doc """
  Given a tag, return whether to render the contens verbatim instead of formatting them.
  Specifically, don't modify contents of macro components or <pre> and <code> tags.
  """
  def render_contents_verbatim?("#" <> _), do: true
  def render_contents_verbatim?("pre"), do: true
  def render_contents_verbatim?("code"), do: true
  def render_contents_verbatim?(tag) when is_binary(tag), do: false
end
