# CSS cheat sheet

Tailwind 4 forms for typography declarations whose utility is not the obvious one or does not exist. Where no utility exists, the arbitrary-value form is shown. Plain CSS, CSS Modules, styled-components and StyleX codebases use the declaration as written.

| Declaration | Tailwind |
| --- | --- |
| `font-synthesis: none` (after verifying fallbacks and emphasis) | `[font-synthesis:none]` |
| `font-feature-settings` | `[font-feature-settings:"ss01"]` |
| `font-variation-settings` | `[font-variation-settings:"GRAD"_80]` |
| `font-optical-sizing: auto` | none needed; it is the default |
| `font-variant-caps` | `[font-variant-caps:small-caps]` |
| `font-variant-position` | `[font-variant-position:super]` |
| `text-box: trim-both cap alphabetic` | `[text-box:trim-both_cap_alphabetic]` |
| `max-width` capping the measure at ~60–75 characters | `max-w-prose` (`65ch`), or `max-w-xl` / `max-w-2xl` |
| `overflow-wrap: break-word` | `break-words` |
| `hyphens: auto` (follows the element's `lang`) | `hyphens-auto` |
| `text-underline-position: from-font` | `[text-underline-position:from-font]` |
| `text-decoration-thickness: from-font` | `decoration-from-font` |
| `text-decoration-skip-ink: auto` (the default) | `[text-decoration-skip-ink:auto]` |
| `-webkit-text-stroke` | `[-webkit-text-stroke:1px_black]` |
| `initial-letter` | `[initial-letter:3]` |
| `user-select: none` (verified drag or gesture conflict only) | `select-none` |
