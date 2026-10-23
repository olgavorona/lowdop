# Harmless Apps Site

A static Astro site for Harmless Apps and the Denny's Maze iOS app.

## Run locally

```bash
cd site
npm install
npm run dev
```

The development server normally runs at `http://localhost:4321`.

## Build and check

```bash
cd site
npm run check
npm run build
```

The generated site is in `site/dist/`.

## Languages

`npm run build` creates English pages and static copies for the languages listed in
`src/data/locales.json`. German is currently available under `/de/`. The language
picker keeps visitors on the same page when they switch languages. Text and metadata
translations live in `translations/<code>.json`; PDF, PNG, and ZIP assets are shared
across languages. The build fails if a listed language is missing a translation.

To check the language picker locally, use the production preview:

```bash
npm run build
npm run preview
```

To extract English strings after changing content:

```bash
npm exec astro build
node scripts/localize.mjs --extract > /tmp/site-english-strings.json
```

Add new translations to `translations/de.json` and run `npm run build` again. To add
another language, add its code, native name, and Open Graph locale to
`src/data/locales.json`, create `translations/<code>.json`, and build the site.
The picker, alternate links, and sitemap use the same language list.

## Traffic analytics

The site uses three analytics sources:

- Vercel Web Analytics for page views and basic referrers.
- TelemetryDeck Web for page views, UTM parameters, App Store and Amazon link clicks, and printable download link clicks.
- App Store Connect for product page views, downloads, sales, and retention associated with Apple campaign links.

Create a separate TelemetryDeck app for the website. Then add these values to a
local `site/.env` file and to the Vercel project's environment variables:

```dotenv
PUBLIC_TELEMETRYDECK_WEB_APP_ID=your-website-app-id
PUBLIC_TELEMETRYDECK_NAMESPACE=your-organization-namespace
PUBLIC_APPLE_PROVIDER_TOKEN=your-apple-provider-token
```

These values are public: they appear in HTML or URLs. Do not put private
TelemetryDeck or App Store Connect keys here.

The Apple provider token comes from a campaign link created in App Store Connect:
`Analytics` → `Acquisition` → `Campaigns` → `+`. Copy the numeric `pt` parameter
from that link. The site adds `pt`, `ct`, and `mt=8` to Denny's Maze links.

If the variables are absent, the site still works: TelemetryDeck Web is not
loaded, and App Store links have no campaign attribution.

TelemetryDeck click signals are `website.appStoreClicked`,
`website.amazonClicked`, and `website.printableDownloadClicked`. All include
`path`, `utm_source`, `utm_medium`, and `utm_campaign`. App Store clicks also
include `placement` and `campaign`; Amazon clicks include `placement`; printable
clicks include `file`, `format`, `kind` (`archive` or `maze`), and `placement`.
The printable signal records a click, not a completed download.

## SEO metadata

Global settings are in `src/data/site.ts` and `astro.config.mjs`. The site config
contains the site URL, App Store URL, brand details, default title and description,
and default Open Graph image.

Page metadata is set with `buildMeta(...)` in the relevant files under
`src/pages/`. Structured data helpers are in `src/lib/seo.ts`.

Before changing the production domain, check the site URL in `src/data/site.ts`,
`astro.config.mjs`, `scripts/localize.mjs`, and `public/robots.txt` so canonical,
Open Graph, alternate, and sitemap URLs agree.

## Deployment

Deploy through the GitHub CI/CD integration configured for the hosting provider.
For Vercel, import the GitHub repository and use these project settings:

- Root Directory: `site`
- Framework Preset: `Astro`
- Build Command: `npm run build`
- Output Directory: `dist`

Check that `npm run check` and `npm run build` pass before merging a deployment
change. After the provider creates a preview URL, verify the home page, internal
links, `robots.txt`, `sitemap.xml`, App Store links, and mobile layout.

To connect a GoDaddy domain, add it under Vercel `Settings` → `Domains`, then add
the DNS records shown by Vercel in GoDaddy. Use the current values shown by Vercel
rather than copying old DNS examples. Once the domain is live, update the site URL
and `robots.txt` if needed, then deploy through GitHub again.

Netlify is another option: set Base directory to `site`, Build command to
`npm run build`, and Publish directory to `dist`. GitHub Pages can also host the
static output.

## Post-deployment checks

1. The home page opens on the production domain.
2. App Store calls to action lead to the correct listing.
3. `sitemap.xml` and `robots.txt` open.
4. Each page has its own title and description.
5. Structured data appears in the page HTML.
6. The menu and content fit on a phone.
7. Language picker links open the equivalent localized page.

Before requesting indexing, verify the final domain in Google Search Console,
submit the sitemap, and inspect a few pages with URL Inspection.

## Content notes

- Copy avoids hype and medical claims.
- Pages include internal links to related content.
- `robots.txt` and `sitemap.xml` are included.
