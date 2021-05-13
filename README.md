# SurfaceFormatter

[![Build Status](https://github.com/surface-ui/surface_formatter/workflows/CI/badge.svg)](https://github.com/surface-ui/surface_formatter/actions?query=workflow%3A%22CI%22)
[![hex.pm](https://img.shields.io/hexpm/v/surface_formatter.svg)](https://hex.pm/packages/surface_formatter)
[![hex.pm](https://img.shields.io/hexpm/l/surface_formatter.svg)](https://hex.pm/packages/surface_formatter)

A code formatter for https://hex.pm/packages/surface

The complete documentation for SurfaceFormatter is located [here](https://hexdocs.pm/surface_formatter/).

## Installation

Add as a dependency in `mix.exs`:

```elixir
defp deps do
  [
    {:surface_formatter, "~> 0.4.1"}
  ]
end
```

## Usage

```bash
$ mix surface.format
```

See `mix surface.format` for documentation of flags and configuration options.

## Formatting rules

The formatter mostly follows these rules:

- Only formats code inside of `~H"""` blocks and `.sface` files.
- Child nodes are typically indented 2 spaces in from their parent.
- Interpolated Elixir code (inside `{{ }}` brackets) is formatted by the
  [official Elixir formatter](https://hexdocs.pm/elixir/Code.html#format_string!/2).
- HTML attributes are put on separate lines if the line is too long.
- Retains "lack of whitespace" such as `<p>No whitespace between text and tags</p>`.
- Collapses extra newlines down to at most one blank line.

See `Surface.Formatter.format_string!/2` for further documentation.

## Example at a glance

Out of the box, Surface code that looks like this:

```html
 <RootComponent with_many_attributes={{ true }} causing_this_line_to_wrap={{ true}} because_it_is_too_long={{ "yes" }}>
   <!-- An HTML comment -->
   {{#An Elixir comment}}



   <div :if={{@show_div}}
   class="container">
       <p> Text inside paragraph    </p>
    <span>Text touching parent tags</span>
   </div>

<Child  items={{[%{name: "Option 1", key: 1}, %{name: "Option 2", key:  2},    %{name: "Option 3", key: 3}, %{name: "Option 4", key: 4}]}}>
  Contents
</Child>
</RootComponent>
```

will be formatted like this:

```html
<RootComponent
  with_many_attributes
  causing_this_line_to_wrap
  because_it_is_too_long="yes, this line is long enough to wrap"
>
  {{ # An Elixir comment }}

  <div :if={{ @show_div }} class="container">
    <p>
      Text inside paragraph
    </p>
    <span>Text touching parent tags</span>
  </div>

  <Child items={{[
    %{name: "Option 1", key: 1},
    %{name: "Option 2", key: 2},
    %{name: "Option 3", key: 3},
    %{name: "Option 4", key: 4}
  ]}}>
    Contents
  </Child>
</RootComponent>
```

## Formatting `.sface` files

If your project includes `.sface` files, use the `:surface_inputs` option (instead of `:inputs`) in
`.formatter.exs` to specify patterns for files containing Surface code.

Without `:surface_inputs`, the formatter falls back to `:inputs`.
Including `.sface` files in `:inputs` causes `mix format` to crash.

```elixir
# Example .formatter.exs preventing `mix format` from crashing on .sface files
[
  surface_line_length: 120,
  import_deps: [:ecto, :phoenix, :surface],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  surface_inputs: ["{lib,test}/**/*.{ex,sface}"],
  subdirectories: ["priv/*/migrations"]
]
```
