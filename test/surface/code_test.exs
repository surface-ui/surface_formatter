defmodule Surface.CodeTest do
  use ExUnit.Case

  def test_formatter(input_code, expected_formatted_result) do
    expected_formatted_result = "\n" <> expected_formatted_result
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

  test "interpolation in attributes is formatted as expected" do
    test_formatter(
      """
      <div class={{[1, 2, 3]}} />
      """,
      """
      <div class={{ [1, 2, 3] }} />
      """
    )

    test_formatter(
      """
      <div class={{foo: "foofoofoofoofoofoofoofoofoofoo", bar: "barbarbarbarbarbarbarbarbarbarbar", baz: "bazbazbazbazbazbazbazbaz"}} />
      """,
      """
      <div class={{
        foo: "foofoofoofoofoofoofoofoofoofoo",
        bar: "barbarbarbarbarbarbarbarbarbarbar",
        baz: "bazbazbazbazbazbazbazbaz"
      }} />
      """
    )
  end

  test "interpolation in attributes of deeply nested elements" do
    test_formatter(
      """
      <section>
      <div>
      <p class={{["foofoofoofoofoofoofoofoofoofoo", "barbarbarbarbarbarbarbarbarbarbar", "bazbazbazbazbazbazbazbaz"]}} />
      </div>
      </section>
      """,
      """
      <section>
        <div>
          <p class={{[
            "foofoofoofoofoofoofoofoofoofoo",
            "barbarbarbarbarbarbarbarbarbarbar",
            "bazbazbazbazbazbazbazbaz"
          ]}} />
        </div>
      </section>
      """
    )
  end

  test "boolean, integer, and string literals in attributes are not wrapped in Surface brackets" do
    test_formatter(
      """
      <Component true_prop={{ true }} false_prop={{ false }}
      int_prop={{12345}} str_prop={{ "some_string_value" }} />
      """,
      """
      <Component true_prop false_prop=false int_prop=12345 str_prop="some_string_value" />
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

  test "attributes wrap at 98 characters by default" do
    ninety_seven_chars = """
    <Component foo="..........." bar="..............." baz="............" qux="..................." />
    """

    test_formatter(ninety_seven_chars, ninety_seven_chars)

    test_formatter(
      """
      <Component foo="..........." bar="..............." baz="............" qux="...................." />
      """,
      """
      <Component
        foo="..........."
        bar="..............."
        baz="............"
        qux="...................."
      />
      """
    )
  end

  test "a single attribute always begins on the same line as the opening tag" do
    test_formatter(
      """
      <Foo bio={{%{age: 23, name: "John Jacob Jingleheimerschmidt", title: "Lead rockstar 10x ninja brogrammer", reports_to: "James Jacob Jingleheimerschmidt"}}}/>
      """,
      """
      <Foo bio={{%{
        age: 23,
        name: "John Jacob Jingleheimerschmidt",
        title: "Lead rockstar 10x ninja brogrammer",
        reports_to: "James Jacob Jingleheimerschmidt"
      }}} />
      """
    )

    test_formatter(
      """
      <Foo urls={{["https://hexdocs.pm/elixir/DateTime.html#content", "https://hexdocs.pm/elixir/Exception.html#content"]}}/>
      """,
      """
      <Foo urls={{[
        "https://hexdocs.pm/elixir/DateTime.html#content",
        "https://hexdocs.pm/elixir/Exception.html#content"
      ]}} />
      """
    )

    test_formatter(
      """
      <Foo bar={{baz: "BAZ", qux: "QUX", long: "LONG", longer: "LONGER", longest: "LONGEST", wrapping: "WRAPPING", next_line: "NEXT_LINE"}} />
      """,
      """
      <Foo bar={{
        baz: "BAZ",
        qux: "QUX",
        long: "LONG",
        longer: "LONGER",
        longest: "LONGEST",
        wrapping: "WRAPPING",
        next_line: "NEXT_LINE"
      }} />
      """
    )

    test_formatter(
      """
      <Foo bar="A really really really really really really long string that makes this line longer than the default 98 characters"/>
      """,
      """
      <Foo bar="A really really really really really really long string that makes this line longer than the default 98 characters" />
      """
    )
  end

  test "(bugfix) a trailing interpolation does not get an extra newline added" do
    test_formatter(
      """
      <p>Foo</p><p>Bar</p>{{ baz }}
      """,
      """
      <p>Foo</p><p>Bar</p>{{ baz }}
      """
    )
  end
end
