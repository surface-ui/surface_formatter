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

## Formatting Rules

The formatter mostly follows these basic rules. See [Formatting Behaviors](#formatting-behaviors) for a more thorough explanation.

- Only formats code inside of `~H"""` blocks.
- Child nodes are indented 2 spaces in from their parent.
- Interpolated Elixir code (inside `{{ }}` brackets) is formatted by the official Elixir formatter.
- HTML attributes are put on separate lines if the line is too long.
- Retains "lack of whitespace" such as `<p>No whitespace between text and tags</p>`.
- Collapses extra newlines down to at most one blank line.

## Mix Task Features

Most of the options from `mix format` are available. See the [documentation for mix format](https://hexdocs.pm/mix/master/Mix.Tasks.Format.html#module-task-specific-options).

```bash
$ mix surface.format --check-formatted
** (Mix) mix surface.format failed due to --check-formatted.
The following files are not formatted:
  * path/to/component.ex
  * path/to/file.sface
```

```bash
$ mix surface.format --dry-run
```

```bash
$ mix surface.format --dot-formatter path/to/.formatter.exs
```

You can also use the same syntax as `mix format` for specifying which files to
format:

```bash
$ mix surface.format path/to/file.ex "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}"
```

## Formatting `.sface` files

The Elixir formatter will crash if you add `.sface` files to your `inputs` patterns
in `.formatter.exs`. If you're using `.sface` files, use `surface_inputs` in
`formatter.exs` to specify patterns for your files containing Surface code.

```elixir
# Example .formatter.exs
[
  surface_line_length: 120,
  import_deps: [:ecto, :phoenix, :surface],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  surface_inputs: ["{lib,test}/**/*.{ex,sface}"],
  subdirectories: ["priv/*/migrations"]
]
```
