# Shared AI Handoff

Use this file to share active working state between Claude and Codex.

Update it at the end of any meaningful work session when there is unfinished work, a discovered risk, or useful context that the next assistant should not have to rediscover.

## How To Use

- Read this file before starting substantial work.
- Append or refresh the latest entry after finishing a task.
- Keep entries short, factual, and current.
- Do not put secrets in this file.

## Entry Template

```md
## YYYY-MM-DD HH:MM TZ - Agent

### What Changed
- Brief summary of completed work

### Current State
- What is true now
- What was verified

### Open Issues
- Bugs, blockers, risks, or uncertainty

### Next Steps
- Concrete next actions for the next agent

### Commands / References
- Commands that were useful
- Files worth reading first
```

## Latest Entry

## 2026-04-28 - Claude

### What Changed
- Added `PaywallSource` enum to `Analytics.swift` (`onboarding`, `bookshelf`, `levels`, `account`) — paywall analytics now carry a `source` field everywhere.
- `PaywallView` now requires a `source: PaywallSource` parameter; all call sites updated (`BookshelfView`, `LabyrinthGridView`, `LabyrinthListView`, `AccountView`).
- Replaced stale `Paywall.shown` events fired on entry tap with `Paywall.entryTapped` (pre-gate) + `Paywall.shown` (on view appear) for accurate funnel tracking.
- Added onboarding analytics: `Onboarding.tutorialShown`, `Onboarding.tutorialCompleted`, `Onboarding.tutorialSkipped`, `Onboarding.startFreeTapped`.
- `LabyrinthViewModel.init` now accepts `completionRadiusBase: CGFloat` (default 30); onboarding tutorial uses 80 so the end zone is easier to hit.
- Updated several forest labyrinth JSON files (043, 049, 058) with improved maze path data.
- Deleted completed `work/pack-monetization/` feature folder.

### Current State
- Analytics funnel is fully instrumented: shown → entryTapped → purchaseAttempted → purchaseSucceeded across all sources.
- All `PaywallView` presentations pass a source; no compile errors expected.
- Onboarding tutorial completion radius is 80 (was 30) — much easier to trigger.
- Forest maze content for 043/049/058 regenerated.

### Open Issues
- `BookshelfView` still has presentational pack metadata (`title`, gradients, icon) hardcoded locally.
- Space imagesets (`finn_space`, `stella_space`, `pearl_space`, `shelly_space`) still emit actool warnings for extra files.
- No unit tests for `LabyrinthLoader` manifest decoding or bundle integrity.

### Next Steps
- Run in simulator to confirm paywall analytics fire correctly and onboarding tutorial is completable.
- If desired, move pack visual metadata out of `BookshelfView` into manifest.
- Clean unassigned extra files from space imagesets to remove actool warnings.

### Commands / References
- `xcodebuild build -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1'`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Services/Analytics.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Views/PaywallView.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Views/OnboardingView.swift`

## 2026-04-05 15:06 +07 - Codex

### What Changed
- Updated the first story of each forest 4-story arc so it is explicitly the character-meeting story.
- Changed Maya's opener (`041`) from a flower collect to a plain maze intro so the pack no longer starts with flowers.
- Regenerated forest JSON content in both `content-generator/output/labyrinths` and the app bundle resources.
- Regenerated ElevenLabs audio for the updated arc-opening stories: `041`, `045`, `049`, `053`, and `057`.

### Current State
- Forest arc openers are now:
- `041` meet Maya
- `045` meet Finn
- `049` meet Pip
- `053` meet Birch
- `057` meet Glow
- Those five opener stories now have `item_rule = nil`; Maya no longer starts with a collect maze.
- `xcodebuild test -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1' -derivedDataPath /tmp/lowdop-cli-tests -only-testing:LowDopamineLabyrinthTests` passed on 2026-04-05.

### Open Issues
- The broader project still has pre-existing asset-catalog warnings for extra space image files.
- `BookshelfView` still duplicates pack presentation metadata locally.

### Next Steps
- If the user wants tighter narrative polish, continue tightening stories `042-044`, `046-048`, etc. around each character arc after the new introduction stories.
- If needed, preview the updated forest pack in the simulator to confirm the on-screen order matches the loader fix.

### Commands / References
- `python3 content-generator/generate_forest_pack.py`
- `python3 content-generator/generate_forest_pack.py --output LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/denny_041_easy.json`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/denny_045_easy.json`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/denny_049_easy.json`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/denny_053_easy.json`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/denny_057_easy.json`

## 2026-04-05 14:30 +07 - Codex

### What Changed
- Fixed pack loading order so stories stay in manifest/story-number order instead of being interleaved by `itemRule`. This preserves the intended 4-story per-character forest arcs in the UI.
- Extended `content-generator/generate_characters.py` to support `--universe forest` and optional `--remove-background` processing with `rembg`.
- Tightened the forest character prompts in `content-generator/characters/denny_forest_universe.json` to match the existing single-character transparent asset workflow more closely.
- Generated and installed new forest character assets into Xcode: `denny_forest`, `maya_forest`, `fox_forest`, `frog_forest`, `beaver_forest`, and `firefly_forest`.
- Re-ran the unit test target after the ordering and asset changes.

### Current State
- Forest stories should now appear in sequence as character arcs: Maya `041-044`, fox `045-048`, frog `049-052`, beaver `053-056`, firefly `057-060`.
- The app now has real forest character assets in `Assets.xcassets` instead of relying only on emoji/color fallbacks.
- Forest character PNGs were background-cleaned with `rembg` before installation.
- `xcodebuild test -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1' -derivedDataPath /tmp/lowdop-cli-tests -only-testing:LowDopamineLabyrinthTests` passed on 2026-04-05.

### Open Issues
- The generated forest art matches the repo pipeline and transparency workflow, but visual style is still a little mixed across the project because the older catalog assets vary between generations.
- `Assets.xcassets` still emits pre-existing warnings for unassigned children in some `*_space.imageset` folders (`finn_space`, `stella_space`, `pearl_space`, `shelly_space`).
- `BookshelfView` still hardcodes pack presentation metadata locally even though lock logic is now centralized.

### Next Steps
- If the forest art needs tighter visual consistency, regenerate selected forest assets with more constrained prompts or replace with hand-picked finals.
- Clean the unassigned extra files from the affected space image sets to remove `actool` warnings.
- If desired, move pack presentation metadata out of `BookshelfView` so pack visuals are also source-of-truth driven.

### Commands / References
- `python3 content-generator/generate_characters.py --universe forest --install --remove-background`
- `xcodebuild test -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1' -derivedDataPath /tmp/lowdop-cli-tests -only-testing:LowDopamineLabyrinthTests`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Services/LabyrinthLoader.swift`
- `content-generator/generate_characters.py`
- `content-generator/characters/denny_forest_universe.json`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Assets.xcassets`

## 2026-04-05 14:15 +07 - Codex

### What Changed
- Kept the forest pack in the per-character arc structure the user asked for: one character gets a 4-story mini-arc, then the pack moves to the next forest character.
- Removed the remaining duplicated pack-lock rules from the main UI flow so grid selection and in-game next navigation now use the centralized `GameViewModel` lock check.
- Removed the old adventure inference based on story number thresholds and switched story metadata to detect adventure status from actual labyrinth content (`itemRule` presence).
- Removed duplicated `isFree` monetization state from `BookshelfView` pack config and derived pack lock state from loaded story metadata instead.
- Updated unit tests to stop depending on the old `>= 11` heuristic and added coverage for the centralized labyrinth-lock helper.

### Current State
- Forest content remains organized as sequential 4-story arcs by character, starting with Maya and then moving character by character through the pack.
- `GameViewModel` now tracks `currentPackFreeStories` from manifest data when a pack loads, and both grid and in-game next navigation read from that central lock logic.
- `LabyrinthLoader.loadStories` now marks `isAdventure` from actual content instead of story-number assumptions.
- `xcodebuild test -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1' -derivedDataPath /tmp/lowdop-cli-tests -only-testing:LowDopamineLabyrinthTests` passed on 2026-04-05.

### Open Issues
- Forest character art still uses fallback marker rendering instead of dedicated asset catalog art.
- `BookshelfView` still has presentational pack metadata duplicated locally (`title`, gradients, decoration, icon). The monetization duplication is gone, but visual metadata is still hardcoded there.
- There is still no direct unit coverage for manifest decoding or bundle integrity.

### Next Steps
- If needed, replace forest fallback markers with real forest character assets.
- Consider moving pack presentation metadata out of `BookshelfView` into manifest or a dedicated configuration source if you want a single source of truth for pack visuals too.
- Add loader/content integrity tests so missing generated JSON or audio regressions fail fast.

### Commands / References
- `xcodebuild test -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1' -derivedDataPath /tmp/lowdop-cli-tests -only-testing:LowDopamineLabyrinthTests`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/ViewModels/GameViewModel.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Services/LabyrinthLoader.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Views/BookshelfView.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Views/LabyrinthGridView.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Views/LabyrinthListView.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinthTests/GameViewModelTests.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinthTests/StoryInfoTests.swift`

## 2026-04-05 14:10 +07 - Codex

### What Changed
- Replaced the simplified forest generator with Claude's original Maya-based forest generator structure and restored the intended richer maze styles.
- Reworked the full `forest_adventures` pack so stories `041-044` are the restored Maya arc and stories `045-060` continue in the same style across fox, frog, beaver, and firefly arcs.
- Added deterministic generation for forest mazes so the pack content is reproducible across runs.
- Added `maya_forest` fallback rendering in `CharacterMarkerView` and expanded `content-generator/characters/denny_forest_universe.json` with the added forest characters used by the generator.
- Regenerated the app forest JSON files, regenerated ElevenLabs audio for stories `041-060`, and synced that audio into `content-generator/output/labyrinths/audio`.
- Re-ran the unit test target after the final content and audio update.

### Current State
- `forest_adventures` contains 20 stories (`41-60`) with `free_stories: 0`.
- The current forest pack structure is:
- `041-044`: Maya arc, preserving Claude's original style mix: organic collect, corridor, walls, avoid.
- `045-048`: Finn the fox arc.
- `049-052`: Pip the frog arc.
- `053-056`: Birch the beaver arc.
- `057-060`: Glow the firefly arc, ending with a leaf-shaped organic collect maze in story `060`.
- Forest audio for stories `041-060` was regenerated with ElevenLabs and written into the app bundle audio folder.
- `xcodebuild test -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1' -derivedDataPath /tmp/lowdop-cli-tests -only-testing:LowDopamineLabyrinthTests` passed on 2026-04-05.

### Open Issues
- The forest pack still relies on fallback emoji/color markers instead of dedicated asset-catalog character art for Maya and the new forest characters.
- Pack locking/free-story behavior is still duplicated in UI code instead of consistently following manifest data.
- README still has stale dependency/build notes unrelated to the forest fix.

### Next Steps
- If visual polish matters for release, add actual forest character image assets for `maya_forest`, `fox_forest`, `frog_forest`, `beaver_forest`, and `firefly_forest`.
- Refactor `BookshelfView`, `LabyrinthGridView`, and `LabyrinthListView` to use manifest-driven pack locking/free-story rules.
- Add content-loader and manifest integrity tests so pack regressions are caught automatically.

### Commands / References
- `python3 content-generator/generate_forest_pack.py`
- `python3 content-generator/generate_forest_pack.py --output LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths`
- `xcodebuild test -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1' -derivedDataPath /tmp/lowdop-cli-tests -only-testing:LowDopamineLabyrinthTests`
- `content-generator/generate_forest_pack.py`
- `content-generator/characters/denny_forest_universe.json`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Views/CharacterMarkerView.swift`

## 2026-04-05 13:55 +07 - Codex

### What Changed
- Completed the forest content takeover from Claude and regenerated the full `forest_adventures` pack for stories `41-60`.
- Added missing forest fallback character mappings in `CharacterMarkerView` so the pack renders sensibly without dedicated raster assets.
- Added the new forest labyrinth JSON files to the Xcode project resource phase and verified generated audio files are present in the bundled `audio` folder.
- Re-ran the unit test target after content/project integration.

### Current State
- `forest_adventures` now contains 20 stories (`41-60`) and `free_stories` is set to `0` in the app manifest.
- The forest pack follows the requested arc shape: 7 pathfinding stories, 5 collect stories, 5 avoid stories, and a final 3-story organic leaf-path arc (`58-60`) that collects leaves.
- App resources include all expected JSON files and audio files for stories `41-60`.
- `xcodebuild test -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1' -derivedDataPath /tmp/lowdop-cli-tests -only-testing:LowDopamineLabyrinthTests` passed on 2026-04-05.

### Open Issues
- Forest-specific character art was not added as asset catalog images. The pack currently relies on emoji/color fallback markers for forest characters.
- Pack monetization and free-story gating are still duplicated in UI logic instead of being driven consistently from manifest data.
- README still contains stale project facts, including the “no external dependencies” note despite `TelemetryDeck/SwiftSDK`.

### Next Steps
- If custom forest art is required, add real image assets for the forest characters and remove the temporary fallback reliance.
- Refactor pack locking so `BookshelfView`, `LabyrinthGridView`, and `LabyrinthListView` use manifest-driven `free_stories` instead of hardcoded `>= 3` checks.
- Add tests for `LabyrinthLoader` manifest decoding and bundle integrity to catch content regressions earlier.

### Commands / References
- `python3 content-generator/generate_forest_pack.py`
- `python3 content-generator/generate_forest_pack.py --output LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths`
- `xcodebuild test -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1' -derivedDataPath /tmp/lowdop-cli-tests -only-testing:LowDopamineLabyrinthTests`
- `content-generator/generate_forest_pack.py`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Views/CharacterMarkerView.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/manifest.json`

## 2026-04-05 13:35 +07 - Codex

### What Changed
- Added `AGENTS.md` to mirror project-level Claude rules in a Codex-readable repo file.
- Reviewed project structure, app architecture, and current unit test coverage.
- Verified the unit test target with `xcodebuild test`.

### Current State
- iOS app target is `LowDopamineLabyrinth`.
- Content bundle currently contains 132 labyrinth entries across 3 packs.
- Unit test target `LowDopamineLabyrinthTests` passed successfully on the available simulator `iPad Air 11-inch (M3)` using simulator id `D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1`.
- The repo currently depends on `TelemetryDeck/SwiftSDK`, so the README note claiming no external dependencies is outdated.

### Open Issues
- README build/test examples still use the stale simulator name `iPad Air`.
- Loader/content integrity is not directly covered by unit tests.
- Shared handoff process existed only implicitly before this file was added.

### Next Steps
- When finishing future work, update this file with the latest state instead of relying on session memory.
- If touching docs, consider fixing outdated dependency and simulator references in `README.md`.
- If improving tests, start with `LabyrinthLoader`, manifest integrity, and content bundle validation.

### Commands / References
- `xcodebuild test -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj -scheme LowDopamineLabyrinth -destination 'platform=iOS Simulator,id=D1CE5302-B5A3-4999-B0FE-FE96E86BA3F1' -derivedDataPath /tmp/lowdop-cli-tests -only-testing:LowDopamineLabyrinthTests`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/LowDopamineLabyrinthApp.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/ViewModels/GameViewModel.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/ViewModels/LabyrinthViewModel.swift`
- `LowDopamineLabyrinth/LowDopamineLabyrinth/Services/LabyrinthLoader.swift`
