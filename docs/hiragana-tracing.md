# Alphabet, number, and hiragana tracing

The bookshelf includes free digits 0–9 in every app language. The free hiragana
collection appears only when the selected app language is Japanese. It contains
the 46 basic modern hiragana in gojūon order (including を and ん). Dakuten,
handakuten, small kana, and combinations are outside this initial collection.

The bookshelf puts all visible maze packs in its first row. The second row
contains letters, hiragana (Japanese only), and numbers, in that order. Each
row scrolls horizontally; short screens can also scroll vertically to reach
both rows.

All three collections use the shared tracing screen and existing free drawing
controls. The upper panel starts with numbered strokes and local direction arrows,
followed by red-dotted copies. On narrow screens the ordered example can also
carry the dots to keep letter pairs readable. The lower panel contains only
light gray guides for independent tracing, using those same curves. Stroke order is
demonstrated visually; drawing is not graded or blocked. Navigation and restart
clear only the current drawing, without storing completion or changing progress.

## Generated Latin handwriting and layout

`scripts/generate_latin_tracing.py` generates all 52 uppercase/lowercase Latin
glyphs as original centreline pen movements. It replaces the old uppercase cue
table and font-based examples. Both cases have complete dotted practice paths
and numbered stroke examples. The construction uses straight lines, cubic
curves, and generated elliptical arcs, with a consistent cap height, x-height,
baseline, and descender line. Lowercase a and g use simple single-storey forms;
i and j keep their dots as separate strokes. The resource is
`Resources/latin-strokes.json`; a review sheet is in `content/tracing/latin-preview.svg`.

The number 1 has two strokes: a short rising diagonal followed by the vertical
downstroke. Row layout measures the actual ink and label width, preserves
letter proportions and baselines, and repeats samples according to available
space. Number rows can fit three or more copies on tablets and additional
copies in landscape. Narrow phones keep larger individual samples. Hiragana
keeps at most two samples per row and uses a distinct white あ bookshelf icon.
In Japanese, the alphabet card uses a white A to distinguish the two collections.

```sh
python3 scripts/generate_latin_tracing.py
python3 scripts/generate_latin_tracing.py --check
```

## Hiragana source and attribution

Hiragana geometry is derived from [KanjiVG](https://kanjivg.tagaini.net/),
Copyright (C) 2009/2010/2011 Ulrich Apel, under
[Creative Commons Attribution–ShareAlike 3.0](https://creativecommons.org/licenses/by-sa/3.0/).
The upstream revision is
[`70a0b7ae0c18ceb5cb358274b029cce0234a43bc`](https://github.com/KanjiVG/kanjivg/tree/70a0b7ae0c18ceb5cb358274b029cce0234a43bc/kanji).
The SVG filenames are five-digit Unicode code points, e.g. `03042.svg` for あ.

Original SVGs, with their notices intact, are in `content/tracing/kanjivg/`.
The original full license is bundled as `Resources/KanjiVG-LICENSE.txt`.
The hiragana grid displays attribution and the source and license URLs as plain text.
The derived `Resources/hiragana-strokes.json` and rendered hiragana diagrams
are distributed under the same CC BY-SA 3.0 license. This attribution applies
to the hiragana data and diagrams, not to unrelated app code or original digit paths.

Changes from upstream: relative and smooth SVG commands are expanded into
absolute cubic controls, and SVG label baselines are adjusted to badge centres.
Curves, pen lifts, and stroke order are preserved. Rendering adds the app's
colours, badges, direction arrows, and evenly spaced practice dots. Handwritten
forms such as き, さ, and り retain their separate strokes instead of relying
on joined shapes from a system font.

## Reproduce and validate the data

```sh
python3 scripts/import_hiragana_tracing.py content/tracing/kanjivg
python3 scripts/import_hiragana_tracing.py content/tracing/kanjivg --check
```

The importer reads local files only and fails on unsupported geometry or
inconsistent stroke IDs/numbers. All 46 source SVGs are checked. `TracingTests`
also verifies the bundled resource, availability by language, complex curve
preservation, generated Latin glyphs, two-stroke 1, adaptive row bounds,
dot spacing, loop direction, and session navigation. `TracingUITests`
checks bookshelf visibility, routing, reachable grid cells, and drawing controls.
Run UI tests only on a dedicated simulator to preserve installed app data.

Tracing interaction events and duration metrics are documented in
[tracing analytics](tracing-analytics.md).
