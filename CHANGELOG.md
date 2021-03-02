# Changelog

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
