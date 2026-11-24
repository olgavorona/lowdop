# App icon experiment variants

The primary app icon is `AppIconABC`, using the supplied
`Denny_AppIcon_ABC_1024.png`. The following alternate icons are included in
Debug and Release builds:

| Asset name | Artwork |
| --- | --- |
| `AppIcon` | Original crab on a blue background |
| `AppIconHiragana` | User-supplied `Denny_AppIcon_Hiragana_1024.png` |
| `AppIconArabic` | Arabic ا ب ت variant matching the kana icon's crab, maze, and cyan background |

The supplied original and kana PNG files remain unchanged. The Arabic variant
is an opaque 1024 × 1024 RGB PNG. Its artwork was produced with the built-in
image editing tool from the kana bitmap, then downscaled to the required icon
size. The exact edit prompt is saved in
`content/app-icons/arabic-icon-prompt.txt`.
`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` lists all three asset names, and
`ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS` includes them in the app.
The generated `CFBundleIcons` declares them as alternate icons for experiments
using a build containing these assets. The orange `AppIconD` variant and its
build configuration entries have been removed.

Arabic is an alternate icon for the same kind of App Store experiment as the
kana icon. It does not automatically change the Home Screen icon based on app
language. An updated binary containing this asset is required. App Store icon
tests use icons bundled in the current App Store version; see
[Apple's test treatment instructions](https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/configure-test-treatments).
