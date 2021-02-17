defmodule Surface.Code.FormatterTest do
  use ExUnit.Case

  describe "format/1" do
    test "turns parsed/contextualized quoted Surface code into a string as expected" do
      actual =
        Surface.Code.Formatter.format([
          {"Component", [],
           [
             :newline,
             :indent,
             "foo",
             :newline,
             :newline,
             :indent,
             "bar",
             :newline,
             :indent_one_less
           ], %{line: 1, space: ""}}
        ])

      expected = """
      <Component>
        foo

        bar
      </Component>
      """

      assert actual == expected
    end
  end
end
