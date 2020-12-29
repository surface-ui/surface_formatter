defmodule Surface.Code.FormatterTest do
  @moduledoc "Run doctests for `Surface.Code.Formatter`"
  use ExUnit.Case
  doctest Surface.Code.Formatter

  describe "parse/1" do
    test "adds context to whitespace" do
      surface_code = """
      <div> <p> Hello

      Goodbye </p> </div>
      """

      assert [
        {"div", [],
         [
           {:whitespace, :before_child},
           {"p", [],
            [
              {:whitespace, :before_child},
              "Hello",
              {:whitespace, :before_child},
              "Goodbye",
              {:whitespace, :before_closing_tag}
            ], _},
           {:whitespace, :before_closing_tag}
         ], _}
      ] = Surface.Code.Formatter.parse(surface_code)
    end
  end
end
