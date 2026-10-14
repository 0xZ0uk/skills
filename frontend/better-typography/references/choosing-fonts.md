# Choosing fonts

`Display` and `Text` cuts, x-height, fallback stacks for a type change and file formats.

## Display and Text cuts

"Display" in a font's name does not make it a display font. SF Pro and Heldane ship a `Display` variant for large sizes and a `Text` variant for small ones. Use the variant matching the size you are setting.

Monospace is for code and fixed-width identifiers. Numeric columns use `tabular-nums` in the body face instead.

## Same size, different look

Two fonts at the same `font-size` can look like different sizes because their x-heights differ. A large x-height looks bigger, so recheck sizes and line-height after swapping a face.

## Fallback stacks for a type change

When a type change is asked for, two routes. `system-ui` gives each operating system's own interface face. A commercial face such as Helvetica Now is a brand decision and still needs a fallback stack.

```css
/* The platform's native interface face */
html {
  font-family: system-ui, sans-serif;
}

/* Commercial brand face with safe fallbacks */
html {
  font-family: "Helvetica Now", "Helvetica Neue", Arial, sans-serif;
}
```

## Formats

Serve `.woff2` on the web. `.woff` is a fallback only for very old browsers, and `.ttf` or `.otf` ship uncompressed, so use them only when there is no other option. How the files load is the project's concern.
