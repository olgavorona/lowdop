# App Store upload: 1.5.4

The upload completed successfully. Apple processed build 7 as `VALID`, and it
is selected for version 1.5.4. All 28 localized release fields were verified
directly in App Store Connect. The version remains `PREPARE_FOR_SUBMISSION`.
The final CI receipt is `build/appstore/1.5.4-build-7/ci-receipt/release-receipt.json`.

Version 1.5.4 uses build number 7 for the app and its Background Assets extension.
The signed IPA includes English, German, Spanish, Japanese, Simplified Chinese,
Korean, Arabic, Swedish, Finnish, and Dutch. The current Thanksgiving content
is included; the separate Christmas content is excluded. Build 7 also includes
the onboarding analytics fixes documented in `docs/onboarding-analytics.md`.
The Release executable was checked for the new analytics tracker events.

Release text is maintained in `fastlane/release-1.5.4.json` and mirrored in
`fastlane/metadata/*/release_notes.txt` and `promotional_text.txt`.
All 14 storefront localizations have translated What's New and promotional
text: `ar-SA`, `de-DE`, `en-AU`, `en-GB`, `en-US`, `es-ES`, `es-MX`, `fi`,
`fr-CA`, `ja`, `ko`, `nl-NL`, `sv`, and `zh-Hans`. Regional storefront coverage
is separate from the app's ten UI languages. The three new storefronts also
have initial translated descriptions, keywords, and subtitles. Existing
storefront names, descriptions, keywords, URLs, and privacy information are
preserved.

The Swedish, Finnish, and Dutch descriptions were subsequently corrected to
translate the English description in full, preserving its sections, lists,
and claims. The approved description-only update completed through
[GitHub Actions](https://github.com/olgavorona/lowdop/actions/runs/43698499601).
CI snapshots and an independent App Store Connect read verified that keywords
and every other listing attribute remained unchanged across all 14 storefronts.
Build 7 remains selected and the version remains `PREPARE_FOR_SUBMISSION`.
The receipts are under `build/appstore/description-correction-1.5.4`.

The app was archived and exported locally with the existing Apple signing
credentials from the current local `master` checkout. All 132 unit tests and
both onboarding analytics UI journeys passed on the dedicated QA simulator.
Independent checks of the offline captures confirmed screen order, unchanged
language and difficulty acceptance, and parental-gate cancellation/retry counts. The
archive passed a strict code-signature check, and the exported IPA's app and
extension versions were verified. The release package includes SHA-256
checksums for the IPA and the localized metadata.

The authorized upload runs through
[GitHub Actions](https://github.com/olgavorona/lowdop/actions/runs/43677807149)
on the isolated branch `ci/appstore-1.5.4-build-7`. A private staging draft holds
the IPA and metadata; the default branch and the uncommitted app source are
preserved. The workflow validates the package, updates the localized text,
uploads the IPA, waits for Apple processing, and selects the valid build for
the existing App Store version. It does not submit the app for review.

The local archive, export, preflight snapshot, and independent verification are
under `build/appstore/1.5.4-build-7`, together with source fingerprints and
offline analytics captures. The build 6 records remain under `build/appstore/1.5.4`.
CI retains the before/after metadata snapshots and
final release receipt as the `appstore-release-receipt` artifact. Inspect these
records and Apple's build list before retrying an interrupted upload; an
existing matching build is reused instead of uploaded again.
