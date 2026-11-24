# Translation key registry

The current translation inventory is stored in
[`content/localization/keys.json`](../content/localization/keys.json).
Translation handoffs use this saved inventory rather than rebuilding a list
from old translation sheets or scanning the app on every export.

The registry currently contains 745 active keys for the app's interface,
accessibility labels, tracing labels, and 67 stories, with references to all
203 narration tracks. Thanksgiving is included. Christmas remains on its
separate release branch and is excluded from the current inventory.

Each active entry stores its stable `key`, `category`, English `source`,
`context`, and `audio_filename`. Coverage information includes placeholder
tokens and story numbers. The Thanksgiving key group supplies the optional
seasonal reference sheet. Retired key identities remain in the registry to
prevent accidental reuse and to preserve IDs if content returns later.

## Export an existing inventory

```sh
python3 content-generator/export_language_handoff.py
```

This reads the saved registry directly and creates the Korean and Arabic
translation sheets, Thanksgiving reference sheet, guide, coverage report, and
ZIP under `content-generator/localized-audio/translation-files-ko-ar`.
It does not scan Swift files, story JSON, or historical CSVs. Existing sheets
with completed translations are protected from overwriting; use `--output-dir`
to export a fresh copy elsewhere.

## Keep the inventory current

After adding, editing, or removing app UI text, story text, or narration sources:

```sh
python3 content-generator/export_language_handoff.py --sync-registry
python3 content-generator/export_language_handoff.py --check-registry
```

Sync reconciles current app content with the saved inventory. Unchanged
category/source pairs retain their IDs. Changed or removed sources keep their
old identities in `retired_keys`, and returning sources recover their prior IDs.
The check command reports stale content without writing files.

Include the registry change with its corresponding app content change. Keep
seasonal scopes consistent with the branch being prepared. The registry is the
source for translation handoffs; the app's runtime strings and story files are
updated through the normal localization import workflow.

## Import completed Korean and Arabic sheets

```sh
python3 content-generator/import_language_handoff.py --input-dir /path/to/completed-sheets --validate-only
python3 content-generator/import_language_handoff.py --input-dir /path/to/completed-sheets
```

The directory must contain `translations-ko.csv`, `translations-ar.csv`,
`thanksgiving-ko.csv`, and `thanksgiving-ar.csv`. Each full sheet must contain
every active registry key. The Thanksgiving sheets must match their entries in
the full sheets. Import rejects missing, duplicate, or unknown keys, changed
English sources or narration filenames, empty translations, altered format
placeholders, and translated gameplay rule identifiers.

The importer updates the string catalog, UI fallback dictionary, story
localizations, and the 203 narration scripts for each new language. It preserves
existing languages. Original CSVs are archived unchanged under
`content/localization/translations/source`; normalized full sheets and an import
report with input checksums are saved in the parent directory. Running the
importer without `--input-dir` reuses those saved originals.

The supplied sheets retained 37 internal location identifiers in each language.
Their display translations are saved in
`content/localization/display-label-overrides.json`. These are applied only to
unchanged location labels. Internal identifiers and gameplay data stay intact.
Review the normalized sheets when changing these labels.

Korean uses locale `ko` and voice language `ko-KR`; Arabic uses `ar` and `ar-SA`.
Arabic text uses right-to-left layout. Maze coordinates, drawing surfaces,
tracing glyphs, and game navigation keep their original orientation.

Bookshelf rows recreate their scroll state when the layout direction changes.
This keeps Ocean and Thanksgiving visible immediately after selecting Arabic
in onboarding or Account settings. The regression tests also compare each
initial view with the shelf after restarting the app.

## Swedish, Finnish, and Dutch

The app supports Swedish (`sv`, Svenska), Finnish (`fi`, Suomi), and Dutch
(`nl`, Nederlands). Regional device language codes such as `sv-FI` and `nl-BE`
resolve to the corresponding supported language. Their speech locale IDs are
`sv-SE`, `fi-FI`, and `nl-NL`.

All 745 active entries per language were translated directly by Codex from the
English registry, including the interface, accessibility labels, 67 stories,
Thanksgiving, and 203 narration scripts. No external translation service was
used. Character names, tracing glyphs, format placeholders, and gameplay rule
identifiers retain their existing identities. Native language names remain in
their own languages in the language picker.

Completed full sheets and matching Thanksgiving sheets are archived under
`content/localization/translations/source`. Normalized full sheets are in the
parent directory. Validate or reimport these languages with:

```sh
python3 content-generator/import_language_handoff.py --locales sv fi nl --validate-only
python3 content-generator/import_language_handoff.py --locales sv fi nl
```

Fresh handoffs can be exported without overwriting completed translations:

```sh
python3 content-generator/export_language_handoff.py --locales sv fi nl --output-dir /tmp/denny-language-handoff
```

Narration text is saved in `narration-sv.json`, `narration-fi.json`, and
`narration-nl.json` under `content-generator/localized-audio`. The corresponding
asset manifests use IDs `audio-sv`, `audio-fi`, and `audio-nl`. All 609 recordings
were generated with explicit authorization using the existing ElevenLabs voice
and `eleven_turbo_v2_5` model. Every MP3 passed full decoding and 44.1 kHz mono
format checks. The packs total approximately 79 minutes of narration.

Version 1 of each pack was uploaded through
[GitHub Actions](https://github.com/olgavorona/lowdop/actions/runs/43002531577)
and Apple reported `COMPLETE` processing for all three. The receipts and full
audio validation report are in `build/appstore/audio-sv-fi-nl-upload.json` and
`build/appstore/audio-sv-fi-nl-validation.json`. A listening review is available
at `build/languages-review-sv-fi-nl/index.html`.

The focused simulator tests use a dedicated QA simulator and isolated
preferences. In addition to translated content and saved-progress checks, the
narration test downloads all five recently added languages through the local
mock server and verifies that restarting the app restores the downloaded pack
and keeps onboarding usable. These local checks do not test Apple's download
servers.

The App Store review submission runs separately through
[GitHub Actions](https://github.com/olgavorona/lowdop/actions/runs/43011842861).
It uses only the three processed narration version IDs, checks the exact
submission scope, and does not submit an app binary. Submission
`9e4a5c9a-d728-4255-8dda-b5a295f71ef4` was accepted with state
`WAITING_FOR_REVIEW`; its receipt is `build/appstore/audio-sv-fi-nl-review.json`.
Apple approval is required before public distribution. The app's language-picker changes remain local and
require a separate app build and release before customers can select them.

Generating or regenerating recordings sends scripts to ElevenLabs and uses
account credits. Publishing asset packs, pushing app changes, or submitting a
new app build requires authorization. Credentials are stored in ignored local
configuration and encrypted GitHub Actions secrets.

## Narration assets

The import prepares text scripts; it does not generate or publish recordings.
After authorization to send the scripts to ElevenLabs and use account credits:

```sh
python3 content-generator/generate_localized_audio.py ko --env-file content-generator/.env
python3 content-generator/generate_localized_audio.py ar --env-file content-generator/.env
```

Keep credentials in the ignored local `.env` file. Existing recordings are
skipped unless `--overwrite` is provided. Use `--dry-run` to inspect the selected
scripts without contacting the service. Each new pack requires 203 tracks,
including the two onboarding recordings, and uses the existing narration voice
and model settings. Thanksgiving completion recordings include the question,
matching the existing seasonal narration format.

The prepared asset pack IDs are `audio-ko` and `audio-ar`. Generate, validate,
package, and publish their assets through the established release workflow
before releasing a build that requires these downloads. Text import and local
simulator validation do not publish assets or a new app version.

The app checks the selected narration pack's saved availability at launch and
when the language changes. This restores downloaded packs without requiring
an Account visit or another download after restarting. The narration download
UI regression test uses the isolated QA simulator and local mock server to
verify that saved Korean and Arabic packs allow onboarding to continue after
restart.
