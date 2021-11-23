# SurfaceFormatter

[![Build Status](https://github.com/surface-ui/surface_formatter/workflows/CI/badge.svg)](https://github.com/surface-ui/surface_formatter/actions?query=workflow%3A%22CI%22)
[![hex.pm](https://img.shields.io/hexpm/v/surface_formatter.svg)](https://hex.pm/packages/surface_formatter)
[![hex.pm](https://img.shields.io/hexpm/l/surface_formatter.svg)](https://hex.pm/packages/surface_formatter)

A code formatter for [https://hex.pm/packages/surface](https://hex.pm/packages/surface).

The complete documentation for SurfaceFormatter is located [here](https://hexdocs.pm/surface_formatter/).

## Installation

Add `:surface_formatter` as a dependency in `mix.exs`:

```elixir
defp deps do
  [
    {:surface_formatter, "~> 0.6.0"}
  ]
end
```

## Formatter Plugin Usage (Elixir 1.13 and later)

### Configuration

Modify the following in `.formatter.exs`:

- `inputs`  - add patterns for all Surface files
- `plugins` - add `Surface.Formatter.Plugin`

```elixir
# .formatter.exs
[
  ...,
  # match all .sface files and all .ex files with ~F sigils
  inputs: ["lib/**/*.{ex,sface}", ...],
  plugins: [Surface.Formatter.Plugin]
]
```

For documentation of other `.formatter.exs` options, see `Surface.Formatter.Plugin`.

### Usage

```bash
$ mix format
```

(Formats both Elixir and Surface code.)

## Mix Task Usage (Elixir 1.12 and earlier)

### Configuration

Add `surface_inputs` to `.formatter.exs` with patterns for all Surface files:

```elixir
# .formatter.exs
[
  ...,
  # match all .sface files and all .ex files with ~F sigils
  surface_inputs: ["lib/**/*.{ex,sface}", ...]
]
```

If your project does not use `sface` files, you can omit `:surface_inputs` and
specify file patterns in the standard `:inputs` field instead. (`mix
surface.format` will fall back to `:inputs`.) But be warned that including
`.sface` files in `:inputs` causes `mix format` to crash in Elixir 1.12 and
earlier.

For documentation of other `.formatter.exs` options, see `mix surface.format`.

### Usage

```bash
$ mix surface.format
```

## Formatting rules

The formatter mostly follows these rules:

- Only formats code inside of `~F"""` blocks and `.sface` files.
- Child nodes are typically indented 2 spaces in from their parent.
- Interpolated Elixir code (inside `{ }` brackets) is formatted by the
  [official Elixir formatter](https://hexdocs.pm/elixir/Code.html#format_string!/2).
- HTML attributes are put on separate lines if the line is too long.
- Retains "lack of whitespace" such as `<p>No whitespace between text and tags</p>`.
- Collapses extra newlines down to at most one blank line.

See `Surface.Formatter.format_string!/2` for further documentation.

## Example at a glance

Out of the box, Surface code that looks like this:

```html
 <RootComponent with_many_attributes={ true } causing_this_line_to_wrap={ true} because_it_is_too_long={ "yes, this line is long enough to wrap" }>
   <!--   HTML public comment (hits the browser)   -->
   {!--   Surface private comment (does not hit the browser)   --}



   <div :if={ @show_div }
   class="container">
       <p> Text inside paragraph    </p>
    <span>Text touching parent tags</span>
   </div>

<Child  items={[%{name: "Option 1", key: 1}, %{name: "Option 2", key:  2},    %{name: "Option 3", key: 3}, %{name: "Option 4", key: 4}]}>
  Default slot contents
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
  <!-- HTML public comment (hits the browser) -->
  {!-- Surface private comment (does not hit the browser) --}

  <div :if={@show_div} class="container">
    <p>
      Text inside paragraph
    </p>
    <span>Text touching parent tags</span>
  </div>

  <Child items={[
    %{name: "Option 1", key: 1},
    %{name: "Option 2", key: 2},
    %{name: "Option 3", key: 3},
    %{name: "Option 4", key: 4}
  ]}>
    Default slot contents
  </Child>
</RootComponent>
```
