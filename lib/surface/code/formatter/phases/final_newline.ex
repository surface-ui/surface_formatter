defmodule Surface.Code.Formatter.Phases.FinalNewline do
  @behaviour Surface.Code.Formatter.Phase

  def run(nodes) do
    nodes ++ [:newline]
  end
end
