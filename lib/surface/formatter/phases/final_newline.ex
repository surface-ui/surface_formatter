defmodule Surface.Formatter.Phases.FinalNewline do
  @moduledoc "Add a newline after all of the nodes if one was present on the original input"

  @behaviour Surface.Formatter.Phase

  # special case for empty heredocs
  def run([:indent], _opts), do: []

  def run(nodes, opts) do
    suffix =
      opts
      |> Keyword.get(:trailing_newline_on_input, false)
      |> final_newline()

    nodes ++ suffix
  end

  defp final_newline(true), do: [:newline]
  defp final_newline(_), do: []
end
