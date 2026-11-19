# Website translations

Translations are authored directly in the JSON dictionaries using normalized
English source strings as keys. The build translates page text, image alt text,
accessibility labels, metadata, and text within structured data. App names,
numeric ratings, and machine-readable formulas retain their identities.

English, German, Japanese, Swedish, Danish, and Finnish cover the entire website.
Swedish uses `/sv/`, Danish `/da/`, and Finnish `/fi/`. These languages have no
route restrictions, so every English page has a corresponding localized URL.
Arabic and Korean cover the homepage, Denny's Maze, the low-stimulation and offline comparison
guides, the ratings methodology, the ratings index, all eight individual app
reviews, the printables index, and the Christmas and winter maze pages.

The Christmas and winter landing pages are translated into every website
language. Their downloadable worksheets retain the supplied English text; each
localized page discloses this before the downloads. Christmas includes eight PNGs
and a print-ready PDF; winter includes ten PNGs. Each collection has a ZIP download.

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
