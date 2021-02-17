defmodule Surface.Code.Formatter.Phase do
  @moduledoc """
  A phase implementing a single "rule" for formatting code. These are used as
  a sort of middleware, that the formatter pipes the tree of nodes through
  before rendering.

  Some rules may rely on other rules; the moduledoc of the rule should make
  this explicit.
  """

  alias Surface.Code.Formatter

  @doc "The function implementing the phase."
  @callback run([Formatter.formatter_node()]) :: [Formatter.formatter_node()]

  def recurse_on_children(nodes, run) do
    Enum.map(nodes, fn
      {tag, attributes, children, meta} ->
        {tag, attributes, run.(children), meta}

      node ->
        node
    end)
  end
end
