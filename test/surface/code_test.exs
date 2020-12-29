defmodule Surface.CodeTest do
  use ExUnit.Case

  def test_formatter(input_code, expected_formatted_result) do
    assert Surface.Code.format_string!(input_code) == expected_formatted_result
  end

  test "children are indented 1 from parents" do
    test_formatter(
      """
      <div>
      <ul>
      <li>
      <a>
      Hello
      </a>
      </li>
      </ul>
      </div>
      """,
      """
      <div>
        <ul>
          <li>
            <a>
              Hello
            </a>
          </li>
        </ul>
      </div>
      """
    )
  end

  test "Surface brackets for Elixir code still include the original code snippet" do
    test_formatter(
      """
          <div :if = {{1 + 1      }}>
      {{"hello "<>"dolly"}}
      </div>




      """,
      """
      <div :if={{ 1 + 1 }}>
        {{ "hello " <> "dolly" }}
      </div>
      """
    )
  end

  test "Contents of Macro Components are preserved" do
    test_formatter(
      """
      <#MacroComponent>
      * One
      * Two
      ** Three
      *** Four
              **** Five
        -- Once I caught a fish alive
      </#MacroComponent>
      """,
      """
      <#MacroComponent>
      * One
      * Two
      ** Three
      *** Four
              **** Five
        -- Once I caught a fish alive
      </#MacroComponent>
      """
    )
  end

  test "lack of whitespace is preserved" do
    test_formatter(
      """
      <div>
      <dt>{{ @tldr }}/{{ @question }}</dt>
      <dd><slot /></dd>
      </div>
      """,
      """
      <div>
        <dt>{{ @tldr }}/{{ @question }}</dt>
        <dd><slot /></dd>
      </div>
      """
    )
  end

  test "shorthand surface syntax is formatted by Elixir code formatter" do
    test_formatter(
      "<div class={{ foo:        bar }}></div>",
      "<div class={{ foo: bar }} />\n"
    )
  end

  test "boolean, integer, and string literals in attributes are not wrapped in Surface brackets" do
    test_formatter(
      """
      <Component true_prop={{ true }} false_prop={{ false }}
      int_prop={{12345}} str_prop={{ "some_string_value" }} />
      """,
      """
      <Component
        true_prop
        false_prop=false
        int_prop=12345
        str_prop="some_string_value"
      />
      """
    )
  end

  test "float literals are kept in Surface brackets (because it doesn't work not to)" do
    test_formatter(
      """
      <Component float_prop={{123.456}} />
      """,
      """
      <Component float_prop={{ 123.456 }} />
      """
    )
  end

  test "numbers are formatted with underscores per the Elixir formatter" do
    test_formatter(
      """
      <Component int_prop={{1000000000}} float_prop={{123456789.123456789 }} />
      """,
      """
      <Component int_prop=1_000_000_000 float_prop={{ 123_456_789.123456789 }} />
      """
    )
  end
end
