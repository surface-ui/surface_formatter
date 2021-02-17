defmodule Surface.Code.Formatter.Phases.SurroundingWhitespace do
  @moduledoc """
  Adds the initial :indent and trailing newline of an ~H sigil block.
  """

  @behaviour Surface.Code.Formatter.Phase

  def run(nodes) do
    [:indent | nodes] # ++ [:newline]
  end
end
