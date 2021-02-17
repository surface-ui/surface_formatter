defmodule Surface.Formatter.Phase do
  @moduledoc """
  A phase implementing a single "rule" for formatting code. These are used as
  a sort of middleware, that the formatter pipes the tree of nodes through
  before rendering.

  Some rules may rely on other rules; the moduledoc of the rule should make
  this explicit.
  """

  alias Surface.Formatter

  @doc "The function implementing the phase."
  @callback run([Formatter.formatter_node()]) :: [Formatter.formatter_node()]

  @doc """
  Given a list of nodes, find all "element" nodes (HTML elements or Surface components)
  and transform children of those nodes using the given function.

  Useful for recursing deeply through the entire tree of nodes.
  """
  def transform_element_children(nodes, transform) do
    Enum.map(nodes, fn
      {tag, attributes, children, meta} ->
        {tag, attributes, transform.(children), meta}

      node ->
        node
    end)
  end
end
