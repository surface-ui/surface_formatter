defmodule Surface.Code do
  @moduledoc "Utilities for dealing with Surface code"

  @doc """
  Given a string inside of an `~H` sigil, format it.

  Ensures that:

    - HTML/Surface elements are indented to the right of their parents.
    - Attributes are split on multiple lines if the line is too long; otherwise on the same line.
    - Elixir code snippets (inside `{{ }}`) are ran through the Elixir code formatter.
    - Lack of whitespace is preserved, so that intended behaviors are not removed.
      (For example, `<span>Foo bar baz</span>` will not have newlines or spaces added.)
  """
  def format_string!(string, opts \\ []) do
    string
    |> Surface.Code.Formatter.parse()
    |> Surface.Code.Formatter.format(opts)
  end
end
