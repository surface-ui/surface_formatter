defmodule Surface.CodeTest do
  use ExUnit.Case

  def test_formatter(input_code, expected_formatted_result, opts \\ []) do
    expected_formatted_result = "\n" <> expected_formatted_result
    assert Surface.Code.format_string!(input_code, opts) == expected_formatted_result
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

  test "interpolation in string attributes" do
    # Note that the formatter does not remove the extra whitespace at the end of the string.
    # We have no context about whether the whitespace in the given attribute is significant,
    # so we might break code by modifying it. Therefore, the contents of string attributes
    # are left alone other than formatting interpolated expressions.
    test_formatter(
      """
      <Component foo="bar {{@baz}}  "></Component>
      """,
      """
      <Component foo="bar {{ @baz }}  " />
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

  test "attribute wrapping can be configured by :line_length and :surface_line_length (which is given precedence) in opts" do
    test_formatter(
      """
      <Foo bar="bar" baz="baz"/>
      """,
      """
      <Foo
        bar="bar"
        baz="baz"
      />
      """,
      line_length: 20
    )

    test_formatter(
      """
      <Foo bar="bar" baz="baz"/>
      """,
      """
      <Foo
        bar="bar"
        baz="baz"
      />
      """,
      surface_line_length: 20,
      # Demonstrate that surface_line_length is given precedence over line_length
      line_length: 200
    )
  end

  test "a single attribute always begins on the same line as the opening tag" do
    # Wrap in another element to help test whether indentation is working properly

    test_formatter(
      """
      <p>
      <Foo bio={{%{age: 23, name: "John Jacob Jingleheimerschmidt", title: "Lead rockstar 10x ninja brogrammer", reports_to: "James Jacob Jingleheimerschmidt"}}}/>
      </p>
      """,
      """
      <p>
        <Foo bio={{%{
          age: 23,
          name: "John Jacob Jingleheimerschmidt",
          title: "Lead rockstar 10x ninja brogrammer",
          reports_to: "James Jacob Jingleheimerschmidt"
        }}} />
      </p>
      """
    )

    test_formatter(
      """
      <p>
        <Foo urls={{["https://hexdocs.pm/elixir/DateTime.html#content", "https://hexdocs.pm/elixir/Exception.html#content"]}}/>
      </p>
      """,
      """
      <p>
        <Foo urls={{[
          "https://hexdocs.pm/elixir/DateTime.html#content",
          "https://hexdocs.pm/elixir/Exception.html#content"
        ]}} />
      </p>
      """
    )

    test_formatter(
      """
      <p>
      <Foo bar={{baz: "BAZ", qux: "QUX", long: "LONG", longer: "LONGER", longest: "LONGEST", wrapping: "WRAPPING", next_line: "NEXT_LINE"}} />
      </p>
      """,
      """
      <p>
        <Foo bar={{
          baz: "BAZ",
          qux: "QUX",
          long: "LONG",
          longer: "LONGER",
          longest: "LONGEST",
          wrapping: "WRAPPING",
          next_line: "NEXT_LINE"
        }} />
      </p>
      """
    )

    test_formatter(
      """
      <p>
      <Foo bar="A really really really really really really long string that makes this line longer than the default 98 characters"/>
      </p>
      """,
      """
      <p>
        <Foo bar="A really really really really really really long string that makes this line longer than the default 98 characters" />
      </p>
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

  test "Contents of <pre> and <code> tags aren't formatted" do
    # Note that the output looks pretty messy, but it's because
    # we're retaining 100% of the exact characters between the
    # <pre> and </pre> tags, etc.
    test_formatter(
      """
      <p>
      <pre>
          Four
       One
               Nine
      </pre> </p> <div> <code>Some code
      goes    here   </code> </div>
      """,
      """
      <p>
        <pre>
          Four
       One
               Nine
      </pre>
      </p>
      <div>
        <code>Some code
      goes    here   </code>
      </div>
      """
    )
  end

  test "Fix bug in UCBI dev" do
    test_formatter(
      """
      <Parent>
        <Child
          first=123
          second={{[
                  {"foo", application.description},
                  {"baz", application.product_owner}
                ]}}
        />
      </Parent>
      """,
      """
      <Parent>
        <Child
          first=123
          second={{[
            {"foo", application.description},
            {"baz", application.product_owner}
          ]}}
        />
      </Parent>
      """
    )
  end

  test "If any attribute is formatted with a newline, attributes are split onto separate lines" do
    # This is because multiple of them may have newlines, and it could result in odd formatting such as:
    #
    # <Foo bar=1 baz={{[
    #   "bazz",
    #   "bazz",
    #   "bazz"
    # ]}} qux=false />
    #
    # The attributes aren't the easiest to read in that case, and we're making the choice not
    # to open the can of worms of potentially re-ordering attributes, because that introduces
    # plenty of complexity and might not be desired by users.
    test_formatter(
      """
      <Parent>
        <Child
          first=123
          second={{[
                  {"foo", foo},
                  {"bar", bar}
                ]}}
        />
      </Parent>
      """,
      """
      <Parent>
        <Child
          first=123
          second={{[
            {"foo", foo},
            {"bar", bar}
          ]}}
        />
      </Parent>
      """
    )

    test_formatter(
      """
      <Parent>
        <Child first={{[
        {"foo", foo}, {"bar", bar}
        ]}} second=123 />
      </Parent>
      """,
      """
      <Parent>
        <Child
          first={{[
            {"foo", foo},
            {"bar", bar}
          ]}}
          second=123
        />
      </Parent>
      """
    )
  end

  test "tags without children are collapsed if there is no whitespace between them" do
    test_formatter(
      """
      <Foo></Foo>
      """,
      """
      <Foo />
      """
    )

    # Should these be collapsed?
    test_formatter(
      """
      <Foo> </Foo>
      """,
      """
      <Foo>
      </Foo>
      """
    )
  end

  test "interpolated lists in attributes with invisible brackets are formatted" do
    test_formatter(
      ~S"""
      <Component foo={{ "bar", 1, @a_very_long_name_in_assigns <> @another_extremely_long_name_to_make_the_elixir_formatter_wrap_this_expression }} />
      """,
      ~S"""
      <Component foo={{
        "bar",
        1,
        @a_very_long_name_in_assigns <>
          @another_extremely_long_name_to_make_the_elixir_formatter_wrap_this_expression
      }} />
      """
    )
  end

  test "existing whitespace in string attributes is not altered when there are multiple attributes" do
    # The output may not look "clean", but it didn't look "clean" to begin with, and it's the only
    # way to ensure the formatter doesn't accidentally change the behavior of the resulting code.
    #
    # As with the Elixir formatter, it's important that the semantics of the code remain the same.
    test_formatter(
      """
      <Component foo=false bar="a
        b
        c"
      />
      """,
      """
      <Component
        foo=false
        bar="a
        b
        c"
      />
      """
    )
  end

  test "attributes that are a list merged with a keyword list are formatted" do
    test_formatter(
      """
      <span class={{"container", "container--dark": @dark_mode}} />
      """,
      """
      <span class={{ "container", "container--dark": @dark_mode }} />
      """
    )
  end
end
