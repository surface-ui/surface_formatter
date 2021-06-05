defmodule Surface.Formatter.Phases.Indent do
  @moduledoc """
  Adds indentation nodes (`:indent` and `:indent_one_less`) where appropriate.

  `Surface.Formatter.Render.node/2` is responsible for adding the appropriate
  level of indentation. It keeps track of the indentation level based on how
  "nested" a node is. While running Formatter Phases, it's not necessary to
  keep track of that detail.

  `:indent_one_less` exists to notate the indentation that should occur before
  a closing tag, which is one less than its children.

  Relies on `Newlines` phase, which collapses :newline nodes to at most 2 in a row.
  """

  @behaviour Surface.Formatter.Phase
  alias Surface.Formatter.Phase

  def run(nodes, _opts) do
    # Add initial indent on start of first line
    indent([:indent | nodes])
  end

  defp indent(nodes) do
    # Deeply recurse through nodes and add indentation before newlines
    nodes
    |> add_indentation()
    |> Phase.transform_element_children(&indent/1, transform_block: &indent_block/1)
  end

  def add_indentation(nodes, accumulated \\ [])

  def add_indentation([:newline, :newline | rest], accumulated) do
    # Two newlines in a row; don't add indentation on the empty line
    add_indentation(rest, accumulated ++ [:newline, :newline, :indent])
  end

  def add_indentation([:newline], accumulated) do
    # The last child is a newline; add indentation for closing tag
    add_indentation([], accumulated ++ [:newline, :indent_one_less])
  end

  def add_indentation([:newline | rest], accumulated) do
    # Indent before the next child
    add_indentation(rest, accumulated ++ [:newline, :indent])
  end

  def add_indentation([], accumulated) do
    accumulated
  end

  def add_indentation([node | rest], accumulated) do
    add_indentation(rest, accumulated ++ [node])
  end

  def indent_block({:block, "case", expr, sub_blocks, %{has_sub_blocks?: true} = meta}) do
    # "case" is a special case because its sub blocks are indented, unlike `if`
    # and `for`; therefore, the last `:indent_one_less` needs to be removed from
    # the last sub-block and moved to the outer block.
    #
    # This code is a bit hacky but kept the rest of the architecture simpler.
    reversed_indented_sub_blocks =
      sub_blocks
      |> Enum.map(&indent_block/1)
      |> Enum.reverse()

    [last_sub_block | rest] = reversed_indented_sub_blocks
    {:block, "match", match_expr, children, last_meta} = last_sub_block
    modified_sub_blocks = [{:block, "match", match_expr, Enum.slice(children, 0..-2), last_meta} | rest]
    modified_sub_blocks = Enum.reverse(modified_sub_blocks)

    {:block, "case", expr, [:newline, :indent | modified_sub_blocks] ++ [:indent_one_less], meta}
  end

  def indent_block({:block, name, expr, sub_blocks, %{has_sub_blocks?: true} = meta}) do
    sub_blocks = Enum.map(sub_blocks, &indent_block/1)
    {:block, name, expr, [:indent | sub_blocks], meta}
  end

  def indent_block({:block, name, expr, child_nodes, meta}) do
    {:block, name, expr, indent(child_nodes), meta}
  end
end
