# Website translations

Translations are authored directly in the JSON dictionaries using normalized
English source strings as keys. The build translates page text, image alt text,
accessibility labels, metadata, and text within structured data. App names,
numeric ratings, and machine-readable formulas retain their identities.

English, German, and Japanese cover the entire website. Arabic and Korean
currently cover 14 pages each: the homepage, Denny's Maze, the low-stimulation
and offline comparison guides, the ratings methodology, the ratings index,
and all eight individual app reviews.

Route coverage is declared in `src/data/locales.json`. A missing `paths` field
means full coverage; `*` at the end of a pattern matches a route prefix.
Arabic uses `dir="rtl"`; Korean uses `dir="ltr"`. Untranslated destinations
remain in English, and switching to a language unavailable on the current page
opens that language's homepage. Only translated routes receive localized URLs
and sitemap/hreflang entries.

To extend a language, update its route coverage and extract the required keys
after an Astro build with `node scripts/localize.mjs --extract --locale=ar`
(or `--locale=ko`). Add the translations, then run:

```sh
npm run check
npm run build
npm run check:localization
npm run check:seo-lengths
```

The build fails if a published route has missing translations. The localization
check verifies every generated page and sitemap entry, reciprocal language links,
canonical URLs, language direction, structured data, and internal destinations.
