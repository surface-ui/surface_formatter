# SurfaceFormatter

An experimental formatter for https://github.com/msaraiva/surface.

## Installation

Add as a dependency in `mix.exs`:

```elixir
defp deps do
  [
    {:surface_formatter, git: "https://github.com/paulstatezny/surface-formatter.git", tag: "master"}
  ]
end
```

## Usage

```
$ mix surface_format
```

## Features

You can use the same syntax as `mix format` for specifying which files to format. Example:

```
$ mix surface_format path/to/file.ex "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}"
```

## Behavior

The formatter attempts to strike a similar balance to `mix format`.

Here is a non-exhaustive list of behaviors of the formatter:

### Indentation

The formatter ensures that children are indented one tab (two spaces) in from their parent.

### Whitespace

#### Whitespace that exists

As in regular HTML, any amount of whitespace is considered equivalent. There are three exceptions:

1. Macro components (with names starting with `#`, such as `<#Markdown>`)
2. `<pre>` tags
3. `<code>` tags

The contents of those tags are considered whitespace-sensitive, and developers
should sanity check after running the formatter.

#### Whitespace that doesn't exist (Lack of whitespace)

As is sometimes the case in HTML, _lack_ of whitespace is considered
significant.  Instead of attempting to determine which contexts matter, the
formatter consistently retains lack of whitespace. This means that the following

```html
<div><p>Hello</p></div>
```

will not be changed. However, the following

```html
<div> <p> Hello </p> </div>
```

will be formatted as

```html
<div>
  <p>
    Hello
  </p>
</div>
```

because of the whitespace on either side of each tag.

To be clear, this example

```html
<div> <p>Hello</p> </div>
```

will be formatted as

```html
<div>
  <p>Hello</p>
</div>
```

because of the lack of whitespace in between the opening and closing `<p>` tags
and their child content.

#### Splitting children onto separate lines

If there is a not a _lack_ of whitespace that needs to be respected,
the formatter puts separate nodes (e.g. HTML elements, interpolations `{{ ... }}`, etc)
on their own line. This means that

```html
<div> <p>Hello</p> {{1 + 1}} <p>Goodbye</p> </div>
```

will be formatted as

```html
<div>
  <p>Hello</p>
  {{ 1 + 1 }}
  <p>Goodbye</p>
</div>
```

#### Newline characters

The formatter will not add extra newlines unprompted beyond moving nodes onto their own line.
However, if the input code has extra newlines, the formatted will retain them but will collapse
more than one extra newline into a single one.

This means that

```html
<section>


Hello



</section>
```

will be formatted as

```html
<section>

  Hello

</section>
```

It also means that

```html
<section>
  <p>Hello</p>
  <p>and</p>





  <p>Goodbye</p>
</section>
```

will be formatted as

```html
<section>
  <p>Hello</p>
  <p>and</p>

  <p>Goodbye</p>
</section>
```
