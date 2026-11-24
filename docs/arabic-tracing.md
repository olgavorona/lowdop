# Arabic letter tracing

The free Arabic collection contains the 28 base letters in alphabetic order.
It appears only when Arabic is the selected app language, before the Latin
letters and numbers in the tracing row. Latin and number collections remain
available. The Arabic grid and example copies read from right to left; the
letter geometry is never mirrored. Existing navigation, restart, drawing,
collection requirements, and progress behavior are preserved.

This initial collection teaches isolated beginner Naskh-style forms. It does
not teach joined words, positional forms, vowel marks, hamza variants, or
lam-alif. Arabic has no uppercase/lowercase pairing, so each sample contains
one form. The numbered example, direction arrows, dotted copies, and gray
practice guides all use the same original centreline paths. The body precedes
separate dots; paired dots proceed right to left, with the top dot last in
three-dot letters. Kaf has a separate inner mark; tah and zah have a separate
descending ascender. Drawing remains free, without stroke grading.

## Geometry and teaching references

`scripts/generate_arabic_tracing.py` creates the bundled
`Resources/arabic-strokes.json` and `content/tracing/arabic-preview.svg`.
Geometry is original, constructed from cubic curves and straight pen movements
in the shared 109 × 109 writing box. No font outlines or source illustrations
are copied. Handwriting has valid regional variations; these paths use one
consistent beginner formation per letter rather than claiming a single
universal calligraphic order.

References reviewed for formation, direction, and pen lifts:

- [Sacred Learning Arabic writing practice](https://www.sacredlearning.org/wp-content/uploads/Arabic-Writing-Practice.pdf)
- [Mamoun Sakkal's Naskh alphabet teaching notes](https://www.sakkal.com/articles/sakkal_arabic_alphabet.html)

```sh
python3 scripts/generate_arabic_tracing.py
python3 scripts/generate_arabic_tracing.py --check
```

`TracingTests` checks all 28 paths, distinct letters, body/dot ordering, dot
counts and placement, pen direction, bounds, row layout, navigation, and
availability across app languages. `TracingUITests` checks Arabic grid order,
locale routing, free drawing, restart, navigation, and orientation. Run UI
tests on dedicated simulators to preserve installed app preferences/progress.

## Native Arabic screenshots

`TracingUITests/testCaptureArabicRawScreenshots` captures the Arabic alphabet,
tha tracing, three mazes, tutorial, and difficulty page from the running app.
It captures portrait on iPhone and landscape on iPad. Run it on dedicated
simulators to preserve installed app state.

The delivered set is under `build/arabic-screenshots-only`, with seven original
screenshots in each device folder. iPhone images are 1320 × 2868; iPad images
are 2752 × 2064. iPad PNG orientation metadata is applied losslessly so the
files open horizontally. No marketing frames, added copy, resizing, or AI
artwork is used in these screenshots. Screenshot capture does not upload any
images to App Store Connect.
