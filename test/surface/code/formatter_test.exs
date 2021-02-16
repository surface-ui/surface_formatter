defmodule Surface.Code.FormatterTest do
  use ExUnit.Case

  describe "parse/1" do
    test "adds context to whitespace" do
      surface_code = """
      <div>  <p>     Hello

      Goodbye </p> </div>
      """

      assert [
               :indent,
               {"div", [],
                [
                  :newline,
                  :indent,
                  {"p", [],
                   [
                     :space,
                     "Hello",
                     :newline,
                     :newline,
                     :indent,
                     "Goodbye",
                     :space
                   ], _},
                  :newline,
                  :indent_one_less
                ], _}
             ] = Surface.Code.Formatter.parse(surface_code)
    end
  end

  describe "parse_whitespace/1" do
    test "multiple spaces get boiled down to one" do
      actual =
        Surface.Code.Formatter.parse_whitespace(
          """
          Hi         Hello
          """,
          nil,
          nil
        )

      assert actual == ["Hi         Hello", :newline]
    end

    test "correctly tags sections of leading/trailing whitespace in a string" do
      actual =
        Surface.Code.Formatter.parse_whitespace(
          """



          successive newlines



          """,
          nil,
          nil
        )

      expected = [
        :newline,
        :newline,
        :newline,
        "successive newlines",
        :newline,
        :newline,
        :newline,
        :newline
      ]

      assert actual == expected
    end
  end

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
