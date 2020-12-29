defmodule SurfaceFormatterTest do
  use ExUnit.Case
  doctest SurfaceFormatter

  test "children are indented 1 from parents" do
    actual =
      SurfaceFormatter.format_string!("""
      <div>
      <ul>
      <li>
      <a>
      Hello
      </a>
      </li>
      </ul>
      </div>
      """)

    expected = """
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

    assert actual == expected
  end

  test "Surface brackets for Elixir code still include the original code snippet" do
    actual =
      SurfaceFormatter.format_string!("""
          <div :if = {{1 + 1      }}>
      {{"hello "<>"dolly"}}
      </div>
      """)

    expected = """
    <div :if={{ 1 + 1 }}>
      {{ "hello " <> "dolly" }}
    </div>
    """

    assert actual == expected
  end

  test "Contents of Macro Components are preserved" do
    actual =
      SurfaceFormatter.format_string!("""
      <#MacroComponent>
      * One
      * Two
      ** Three
      *** Four
      **** Five
        -- Once I caught a fish alive
      </#MacroComponent>
      """)

    expected = """
    <#MacroComponent>
    * One
    * Two
    ** Three
    *** Four
    **** Five
      -- Once I caught a fish alive
    </#MacroComponent>
    """

    assert actual == expected
  end

  test "lack of whitespace is preserved" do
    actual =
      SurfaceFormatter.format_string!("""
      <div>
      <dt>{{ @question }}</dt>
      <dd><slot /></dd>
      </div>
      """)

    expected = """
    <div>
      <dt>{{ @question }}</dt>
      <dd><slot /></dd>
    </div>
    """

    assert actual == expected
  end

  test "shorthand surface syntax is formatted by Elixir code formatter" do
    actual =
      SurfaceFormatter.format_string!("""
      <div class={{ foo:        bar }}></div>
      """)

    expected = """
    <div class={{ foo: bar }} />
    """

    assert actual == expected
  end
end
