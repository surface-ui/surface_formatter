# Changelog

## v0.7.3 (2021-12-18)

  * Stop endlessly indenting strings with newlines in expression attributes (#54)

## v0.7.2 (2021-12-03)

  * Fix crash with Elixir expression `{...}` on Elixir 1.13 without `:line_length` or `:surface_line_length` (#53)

## v0.7.1 (2021-11-29)

  * Stop adding spaces to indent blank lines in expressions (#51)

## v0.7.0 (2021-11-22)

  * Add `Surface.Formatter.Plugin` for Elixir 1.13 Formatter Plugin support.

## v0.6.0 (2021-10-21)

  * Support tagged expression attributes referencing variables (#47)
  * Require Surface `~> 0.5` instead of `~> 0.5.0` to expand compatibility to `0.6`

## v0.5.4 (2021-08-31)

  * Stop endlessly indenting attribute strings with interpolation whenever node is indented (#43)

## v0.5.3 (2021-08-30)

  * Stop endlessly indenting attribute strings with interpolation (#41)

## v0.5.2 (2021-08-27)

  * Enable reading from stdin (#37)
  * Stop turning `:if={true}` into `:if` (#39)
  * Stop endlessly indenting strings with newlines in list attributes (#40)

## v0.5.1 (2021-07-06)

  * Fix crash with `{#match "string"}` scenario (#32)
  * Stop removing `{/unless}` (#33)
  * Stop formatting contents of `<script>` tags (#34)
  * Stop performing conversion of pre-0.5 `<template>` and `<slot>` to `<#template>` and `<#slot>` (#35)

## v0.5.0 (2021-06-17)

  * Support new Surface syntax (#21 and #22)

## v0.4.1 (2021-05-13)

  * Fix crash related to HTML comments `<!-- -->` (#17)

## v0.4.0 (2021-05-06)

  * Require Surface `v0.4.0` (#16)

## v0.3.2 (2021-05-06)

  * Require Surface `v0.3.2` (#15)

## v0.3.1 (2021-03-06)

  * Require Surface `v0.3.1` (#13)
  * Update list of void elements per Surface `v0.3.1` (#14)

## v0.3.0 (2021-03-02)

  * Require Surface `v0.3.0` (#11)
  * Do not add trailing slash in void elements without a closing tag (#12)

## v0.2.2 (2021-02-17)

  * Fix crash whenever bracket-less keyword lists in attributes contained an interpolation in a key (#9)

## v0.2.1 (2021-02-17)

  * Allow inline elements on the same line with text nodes (#5)
  * Fix issue where extra newlines surrounding text nodes were removed (#7)
  * Organize transformations in formal phases (#8)
  * Stop moving every child onto its own line; replace with limited rules for when to do that (#8)

## v0.2.0 (2021-01-28)

  * Require Surface `v0.2.0` (#2)

## v0.1.1 (2021-01-28)

  * Fix crash for self-closing `<pre>`, `<code>`, and `<#Macro>` tags. (#1)
  * Fix crash when `<pre>`, `<code>`, and `<#Macro>` tags contained components, HTML elements, or interpolations. (#3)

## v0.1.0 (2021-01-25)

  * Initial release
