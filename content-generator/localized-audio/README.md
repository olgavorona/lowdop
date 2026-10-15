# Localized narration packs

## Translation handoff

Run `python3 content-generator/export_translation_files.py` to create
`translations-de.csv` and `translations-es.csv`. Each file has stable keys, source
text, context, and an empty `translation` column. Fill only that column
and keep the keys and other columns intact. Import the CSV as UTF-8 in a spreadsheet;
save it back as UTF-8 CSV when finished. The `audio_filename` column identifies the
198 story tracks and two shared voice-over tracks.

UI rows have no audio filename. Story rows include visible copy, character names,
locations, and narration copy. Some repeated copy is deduplicated; the `context`
column lists every story that uses that source string.

## Current generated packs

For simulator testing, run `python3 scripts/local_audio_mock_server.py` from
the repository root. With the shared Xcode scheme's `-useLocalAudioMockServer`
launch argument, Debug simulator builds download the selected locale's tracks
from `http://127.0.0.1:8765` and cache them in the app. This path is compiled
out for device builds. Keep the server running while downloading a language;
audio remains available from the app cache after download.

The returned sheets are `translations-de-filled.csv` and
`translations-es-filled.csv` at the repository root. Run
`python3 content-generator/import_translations.py` to validate them and regenerate
the string catalog, UI/story localization data, and 200 ElevenLabs scripts per locale.
The narration scripts are 66 stories × instruction, answer, and completion, plus two
shared voice-overs.

Generate or resume either locale with `python3 content-generator/generate_localized_audio.py de`
or `python3 content-generator/generate_localized_audio.py es`. The script skips MP3s
already present. Generated files are in `de/audio` and `es/audio` below this directory,
preserving the English basenames. English narration remains bundled in the app.

The app requests the Apple-hosted Background Assets packs `audio-de` and `audio-es`.
Each locale folder must contain the same narration filenames as
`LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/audio`.

## Package and upload

`python3 scripts/package_localized_audio.py` validates the track sets and creates
`build/appstore/audio-de.aar` and `build/appstore/audio-es.aar` with Apple's
`xcrun ba-package` tool. Configure an App Store Connect API key as described in
[`fastlane/README.md`](../../fastlane/README.md), then run:

```sh
python3 scripts/upload_background_assets.py \
  build/appstore/audio-de.aar build/appstore/audio-es.aar
```

The uploader finds the app by bundle ID, creates or reuses the `audio-de` and
`audio-es` pack records, uploads and commits a new version of each pack, and
prints the versions sent for Apple processing. In App Store Connect, add both
processed pack versions to the same review submission as any app version that
requires the localized narration.
