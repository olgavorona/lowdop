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

The app requests the Apple-hosted Background Assets packs `audio-de` and `audio-es`.
Keep each localized MP3 under its locale directory and preserve the English basename,
for example `de/audio/denny_001_instruction.mp3` and
`es/audio/denny_001_instruction.mp3`. English narration remains in the app bundle.

`python3 content-generator/prepare_localized_audio.py` exports the 198 story
narration scripts (66 stories × instruction, answer, and completion) into
`narration-de-template.json` and `narration-es-template.json`. Translate each value
while preserving the keys. The two shared tracks also need translated source text;
add those source strings to `shared-narration-source.json` before exporting.

Once translated values are complete, the ElevenLabs generation step should create
the MP3 files named by each key. Do not generate files from the English template:
the localized templates need human-reviewed German and Spanish text first.

Before packaging, each locale folder must contain the same narration filenames as
`LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/audio`. Build one
archive from this directory with `xcrun ba-package Manifest-de.json -o audio-de.aar`
and `xcrun ba-package Manifest-es.json -o audio-es.aar`, then upload and submit both
archives as Apple-hosted asset packs in App Store Connect.

The current checkout has templates but no translated narration files yet, so these
manifests cannot be packaged until the German and Spanish recordings are generated
and added.
