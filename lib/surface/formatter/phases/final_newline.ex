defmodule Surface.Formatter.Phases.FinalNewline do
  @behaviour Surface.Formatter.Phase

  def run(nodes) do
    nodes ++ [:newline]
  end
end
