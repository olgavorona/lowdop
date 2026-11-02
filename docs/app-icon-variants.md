# App icon experiment variants

The primary app icon is `AppIconABC`, using the supplied
`Denny_AppIcon_ABC_1024.png`. The following alternate icons are included in
Debug and Release builds:

| Asset name | Artwork |
| --- | --- |
| `AppIcon` | Original crab on a blue background |
| `AppIconHiragana` | User-supplied `Denny_AppIcon_Hiragana_1024.png` |

The supplied 1024 × 1024 opaque PNG files are copied without image changes.
`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` lists both asset names, and
`ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS` includes them in the app.
The generated `CFBundleIcons` declares them as alternate icons for experiments
using a build containing these assets. The orange `AppIconD` variant and its
build configuration entries have been removed.
