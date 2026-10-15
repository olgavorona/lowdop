# App Store release workflow

This release setup uses an App Store Connect API key for uploads and does not
depend on Xcode's interactive account cache.

## One-time local setup

1. In App Store Connect, create an API key with **App Manager** access for the
   app. Save the downloaded `.p8` file outside this repository, preferably in
   `~/.appstoreconnect/private_keys/`.
2. Copy `.env.example` to `.env` and set `ASC_KEY_ID`, `ASC_ISSUER_ID`, and
   `ASC_PRIVATE_KEY_PATH`. The `.env` and `.p8` files are ignored by Git.
3. Never send the private key or its contents in chat.

## Upload narration packs

`fastlane upload_localized_audio` packages the current German and Spanish
tracks and uploads each archive through Apple's Background Assets API. If
`build/appstore/audio-de.aar` and `build/appstore/audio-es.aar` already exist,
the lane uploads those archives directly. This is useful when recovering an
upload or when Xcode's packaging tool is unavailable. The
script creates or reuses the `audio-de` and `audio-es` asset pack records,
creates a version, uploads every reserved file part, and commits the upload.
App Store Connect processes each pack asynchronously after the command returns.

The current Xcode 27 installation on this Mac reports a valid `.json` manifest
path as having the wrong extension. Until Apple fixes that packaging command,
the current archives are available at `/tmp/audio-de.aar` and
`/tmp/audio-es.aar`; copy them into `build/appstore/` before running the lane.

## Build, screenshots, and store listing

- `fastlane upload_build` builds and uploads the iOS app without submitting it.
- `fastlane capture_screenshots` runs the UI screenshot suite described by
  `Snapfile`; screenshot UI tests must call Fastlane Snapshot's `snapshot()`
  helper for each screen to capture.
- `fastlane upload_store_listing` uploads the localized metadata files and
  screenshots prepared under `fastlane/metadata` and `fastlane/screenshots`.

Review remains a separate App Store Connect action. Add the processed versions
of both packs to the same review submission as any app version that requires
them.
