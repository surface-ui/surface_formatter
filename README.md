# SurfaceFormatter

A code formatter for https://hex.pm/packages/surface

## Installation

Add as a dependency in `mix.exs`:

```elixir
defp deps do
  [
    {:surface_formatter, "~> 0.1.0"}
  ]
end
```

## Usage

```bash
$ mix surface.format
```

See `mix surface.format` for documentation of flags and configuration options.

## Formatting Rules

The formatter mostly follows these basic rules.

- Only formats code inside of `~H"""` blocks.
- Child nodes are indented 2 spaces in from their parent.
- Interpolated Elixir code (inside `{{ }}` brackets) is formatted by the
  [official Elixir formatter](https://hexdocs.pm/elixir/Code.html#format_string!/2).
- HTML attributes are put on separate lines if the line is too long.
- Retains "lack of whitespace" such as `<p>No whitespace between text and tags</p>`.
- Collapses extra newlines down to at most one blank line.

The documentation for `Surface.Code.format_string!/2` gives a more thorough
explanation of the behaviors exhibited by the formatter.

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
