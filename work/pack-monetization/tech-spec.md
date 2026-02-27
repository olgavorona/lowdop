---
created: 2026-02-26
status: approved
branch: feature/pack-monetization
size: L
---

# Tech Spec: Pack Monetization

## Solution

Replace the subscription-based monetization (3 subscription tiers) with a one-time pack purchase model ($9.99 per pack). Reduce difficulty levels from 5 to 3 (easy/medium/hard). Introduce a bookshelf screen for pack selection between onboarding and the maze grid. Delete 40 unused maze JSON files (lv2/lv4), rename remaining files and difficulty values to match the new 3-level system.

The core navigation changes from `Onboarding → Grid` to `Onboarding → Bookshelf → Grid`. The grid behavior stays the same — it shows stories for the selected difficulty within a pack. Lock logic changes from time-based (3 free + 1/day) to content-based (stories 1-3 free, rest require pack purchase).

## Architecture

### What we're building/modifying

- **BookshelfView** (NEW) — Pack picker screen showing pack cards in a bookshelf layout. Tap a pack → navigate to grid.
- **StoryInfo model** (NEW) — Data model for story metadata used by the bookshelf (number, title, location, character, free status).
- **UserPreferences** — DifficultyLevel enum reduced from 5 to 3 cases. Free-play tracking removed entirely.
- **SubscriptionManager** — Replace 3 subscription product IDs with 1 non-consumable product ID.
- **PaywallView** — Simplify from multi-plan picker to single-product purchase screen.
- **ContentView** — Add bookshelf as intermediate navigation state.
- **OnboardingView** — Reduce from 5 difficulty cards to 3.
- **LabyrinthLoader** — Add story-based loading for bookshelf metadata.
- **LabyrinthGridView** — Remove free-play banners and daily limits. Lock logic based on pack ownership.
- **GameViewModel** — Remove free-play gating. Add story-complete detection.
- **LabyrinthListView/CompletionView** — Story-complete flow returns to bookshelf.
- **Content files** — 40 JSON files deleted, 40 renamed (files + difficulty field), manifest/samples updated.
- **Content generator** — Config and scripts updated for 3 difficulty levels.

### How it works

```
User opens app
  → Onboarding (pick difficulty: easy/medium/hard)
  → Bookshelf (shows 1 pack, expandable for future packs)
  → Tap pack → Grid (20 stories at selected difficulty)
    → Stories 1-3: unlocked, playable
    → Stories 4-20: locked if pack not purchased
      → Tap locked story → Parental Gate → Paywall ($9.99)
      → Purchase → all stories unlock
    → Tap unlocked story → Game (maze)
    → Complete easy → medium → hard → Story Complete celebration → Bookshelf
```

SubscriptionManager checks for a single non-consumable product via StoreKit 2 `Transaction.currentEntitlements`. The `isPremium` flag drives lock state across the entire app.

## Decisions

### Decision 1: Non-consumable IAP instead of subscription
**Decision:** Use a single non-consumable IAP ($9.99) per pack
**Rationale:** "Buy once, own forever" matches the book/pack metaphor and avoids subscription fatigue for parents
**Alternatives considered:** Keep subscriptions (rejected — user explicitly wants pack model), consumable IAP (rejected — content should stay unlocked permanently)

### Decision 2: Rename files and difficulty values
**Decision:** Rename maze JSON files from `_lv1/_lv3/_lv5` to `_easy/_medium/_hard` and update difficulty fields
**Rationale:** App hasn't been released, no migration needed, cleaner naming
**Alternatives considered:** Keep `_lv1/_lv3/_lv5` naming with mapping in code (rejected — unnecessary complexity)

### Decision 3: Always show bookshelf screen
**Decision:** Show pack picker even with 1 pack
**Rationale:** Establishes the UI pattern for future packs, consistent navigation
**Alternatives considered:** Auto-skip to grid when 1 pack (rejected by user)

### Decision 4: Content-based locking replaces time-based
**Decision:** Stories 1-3 free (unlimited replays), stories 4-20 locked behind pack purchase. No daily limits.
**Rationale:** Simpler model, no "come back tomorrow" friction, clear value proposition
**Alternatives considered:** Keep daily free play (rejected — doesn't fit pack model)

### Decision 5: Difficulty level naming
**Decision:** easy/medium/hard (3 levels)
**Rationale:** Maps to lv1/lv3/lv5 grid sizes (3x4, 6x8, 10x13). Intermediate levels (lv2=4x5, lv4=8x10) had too little difference.
**Alternatives considered:** beginner/intermediate/expert (rejected — user prefers easy/medium/hard)

## Data Models

### StoryInfo (NEW)
```swift
struct StoryInfo: Identifiable {
    let number: Int          // 1-20
    let title: String
    let location: String
    let characterEnd: String // image asset name
    let isFree: Bool         // stories 1-3
    let isAdventure: Bool    // stories 11-20 have collectible items
    let labyrinthIds: [String]

    var id: Int { number }
}
```

### DifficultyLevel (MODIFIED)
```swift
enum DifficultyLevel: String, CaseIterable, Codable {
    case easy, medium, hard

    var pathTolerance: CGFloat {
        switch self {
        case .easy: return 25
        case .medium: return 18
        case .hard: return 12
        }
    }
}
```

### Manifest structure (MODIFIED)
```json
{
  "universe": "denny",
  "total": 60,
  "packs": [
    {
      "id": "ocean_adventures",
      "title": "Ocean Adventures",
      "free_stories": 3,
      "stories": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    }
  ],
  "labyrinths": [
    {"id": "denny_001_easy", "difficulty": "easy", "story": 1, ...},
    ...
  ]
}
```

## Dependencies

### New packages
None — zero external dependencies maintained.

### Using existing (from project)
- **StoreKit 2** — non-consumable IAP (same framework, different product type)
- **SwiftUI** — BookshelfView
- **UserDefaults** — difficulty preference, pack purchase state cached

## Testing Strategy

**Feature size:** L

### Unit tests
- DifficultyLevel enum: 3 cases, correct pathTolerance values
- StoryInfo model: parsing from manifest, isFree logic
- LabyrinthLoader: loadForStory, loadStories, filtering by difficulty
- GameViewModel: story-complete detection, lock state checks
- SubscriptionManager: single product loading, purchase state

### Integration tests
- StoreKit 2 purchase flow using Xcode StoreKit testing configuration
- Purchase → isPremium → grid unlock → persist across restart cycle

### E2E tests
None — visual verification in simulator sufficient.

## Agent Verification Plan

### Verification approach
Build the app, run unit tests, verify content files via file operations, visual verification by user in simulator.

### Per-task verification
| Task | verify: | What to check |
|------|---------|--------------|
| 1 | bash | 60 JSON files exist with correct names and difficulty values |
| 2 | bash | xcodebuild build succeeds |
| 3 | bash | xcodebuild build succeeds |
| 4 | bash | xcodebuild build succeeds |
| 5-10 | bash | xcodebuild build succeeds, tests pass |
| 11 | bash | All tests pass, acceptance criteria met |

### Tools required
xcodebuild, Glob/Grep for file verification

## Risks

| Risk | Mitigation |
|------|-----------|
| App Store non-consumable IAP review requirements | Follow Apple guidelines for non-consumable: restore purchases, clear description |
| Future pack content generation effort | Out of scope. Existing pipeline (generator.py) supports it. |
| UserDefaults migration for difficulty | Graceful fallback: unknown rawValue defaults to .easy |

## Acceptance Criteria

Technical criteria (supplement user-spec criteria):

- [ ] DifficultyLevel enum has exactly 3 cases (easy, medium, hard)
- [ ] No references to beginner/expert in Swift code
- [ ] No lv2 or lv4 JSON files in bundle
- [ ] All remaining JSON files have correct difficulty field (easy/medium/hard)
- [ ] SubscriptionManager uses single non-consumable product ID
- [ ] No subscription-related code remains (auto-renewal, trial periods)
- [ ] Free-play tracking fully removed (no daily limits, no totalFreeLabyrinthsPlayed)
- [ ] BookshelfView renders and navigates to grid
- [ ] All unit tests pass
- [ ] No regressions in existing functionality (maze drawing, path validation, audio, completion)
- [ ] pbxproj updated: deleted files removed, new files added, renamed files updated

## Implementation Tasks

<!-- Tasks are brief scope descriptions. AC, TDD, and detailed steps are created during task-decomposition. -->

### Wave 1 (independent)

#### Task 1: Content file changes
- **Description:** Delete 40 maze JSONs (lv2/lv4), rename remaining 60 files from `_lv1/_lv3/_lv5` to `_easy/_medium/_hard`, update difficulty field inside each JSON, update manifest.json (60 entries + pack structure), update difficulty_samples.json (3 entries). This is the data foundation everything else builds on.
- **Skill:** code-writing
- **Reviewers:** code-reviewer
- **Verify:** bash — file counts, grep for old difficulty names
- **Files to modify:** 60 JSON files, `manifest.json`, `difficulty_samples.json`
- **Files to read:** current `manifest.json`, any `_lv1.json` for structure reference

#### Task 2: DifficultyLevel enum and UserPreferences
- **Description:** Reduce DifficultyLevel from 5 to 3 cases (easy/medium/hard), update pathTolerance values, remove all free-play tracking (totalFreeLabyrinthsPlayed, dailyLabyrinthsPlayed, canPlayToday, recordPlay, freeLabyrinthsRemaining). Add graceful fallback for old UserDefaults values.
- **Skill:** code-writing
- **Reviewers:** code-reviewer, test-reviewer
- **Verify:** bash — xcodebuild build
- **Files to modify:** `UserPreferences.swift`
- **Files to read:** `GameViewModel.swift`, `OnboardingView.swift`, `LabyrinthGridView.swift`

#### Task 3: Content generator updates
- **Description:** Update config.yaml to 3 difficulty levels, update generator.py difficulty_names and ADVENTURE_ITEM_COUNTS, update maze_generator.py extra_connections map. Keeps the content pipeline in sync with the app's new difficulty model.
- **Skill:** code-writing
- **Reviewers:** code-reviewer
- **Verify:** bash — python generator.py --help (no import errors)
- **Files to modify:** `config.yaml`, `generator.py`, `maze_generator.py`
- **Files to read:** current `config.yaml`

### Wave 2 (depends on Wave 1)

#### Task 4: Labyrinth model + StoryInfo + LabyrinthLoader
- **Description:** Add StoryInfo model for bookshelf data. Add storyNumber/levelName computed properties to Labyrinth. Add loadStories() and loadForStory() to LabyrinthLoader. Update loadForDifficulty() for new difficulty names.
- **Skill:** code-writing
- **Reviewers:** code-reviewer, test-reviewer
- **Verify:** bash — xcodebuild build + tests
- **Files to modify:** `Labyrinth.swift`, `LabyrinthLoader.swift`
- **Files to read:** `manifest.json`, `GameViewModel.swift`

#### Task 5: SubscriptionManager — single non-consumable
- **Description:** Replace 3 subscription product IDs with single non-consumable `labyrinth_pack_ocean`. Simplify loadProducts/checkEntitlements for one product. Remove subscription-specific logic (auto-renewal references).
- **Skill:** code-writing
- **Reviewers:** code-reviewer, security-auditor
- **Verify:** bash — xcodebuild build
- **Files to modify:** `SubscriptionManager.swift`
- **Files to read:** `PaywallView.swift`, `GameViewModel.swift`

### Wave 3 (depends on Wave 2)

#### Task 6: OnboardingView — 3 difficulty cards
- **Description:** Reduce onboarding from 5 cards to 3 (easy/medium/hard). Update levelColors, difficulty dots, level numbers. Navigate to bookshelf after selection instead of grid.
- **Skill:** code-writing
- **Reviewers:** code-reviewer
- **Verify:** bash — xcodebuild build
- **Files to modify:** `OnboardingView.swift`
- **Files to read:** `ContentView.swift`, `difficulty_samples.json`

#### Task 7: PaywallView — single product
- **Description:** Replace multi-plan picker with single-product purchase UI. Remove PlanCard, radio selection, selectedProductID, ctaText. Show pack price and "Buy once, play forever" messaging. Keep parental gate, restore purchases, legal links.
- **Skill:** code-writing
- **Reviewers:** code-reviewer, security-auditor
- **Verify:** bash — xcodebuild build
- **Files to modify:** `PaywallView.swift`
- **Files to read:** `SubscriptionManager.swift`, `ParentalGateView.swift`

#### Task 8: BookshelfView + ContentView navigation
- **Description:** Create BookshelfView showing pack card(s) in a bookshelf layout. Integrate into ContentView navigation: Onboarding → Bookshelf → Grid. Single pack for now, designed for multiple. Tapping a pack navigates to the grid for that pack.
- **Skill:** code-writing
- **Reviewers:** code-reviewer
- **Verify:** bash — xcodebuild build
- **Files to modify:** `ContentView.swift` + NEW `BookshelfView.swift`
- **Files to read:** `OnboardingView.swift`, `LabyrinthGridView.swift`, `LabyrinthLoader.swift`

### Wave 4 (depends on Wave 3)

#### Task 9: GameViewModel + LabyrinthGridView — pack-based locking
- **Description:** Remove free-play gating from GameViewModel (canProceed, recordPlay). Add story-complete detection. Update LabyrinthGridView to lock stories 4-20 based on pack purchase instead of daily limits. Remove free-play banners. Update DifficultyPickerSheet to 3 levels.
- **Skill:** code-writing
- **Reviewers:** code-reviewer, test-reviewer
- **Verify:** bash — xcodebuild build + tests
- **Files to modify:** `GameViewModel.swift`, `LabyrinthGridView.swift`
- **Files to read:** `SubscriptionManager.swift`, `LabyrinthLoader.swift`, `UserPreferences.swift`

#### Task 10: LabyrinthListView + CompletionView — story-complete flow
- **Description:** Update LabyrinthListView next-labyrinth logic: after the last difficulty level of a story, return to bookshelf instead of advancing to next story. Add story-complete celebration to CompletionView. Update navigation callbacks.
- **Skill:** code-writing
- **Reviewers:** code-reviewer
- **Verify:** bash — xcodebuild build
- **Files to modify:** `LabyrinthListView.swift`, `CompletionView.swift`
- **Files to read:** `GameViewModel.swift`, `BookshelfView.swift`

#### Task 11: Tests + pbxproj cleanup
- **Description:** Rewrite free-play tests in GameViewModelTests to test pack-based locking. Add tests for StoryInfo, DifficultyLevel, LabyrinthLoader story loading. Update pbxproj: remove 40 deleted files, add renamed files, add BookshelfView.
- **Skill:** code-writing
- **Reviewers:** code-reviewer, test-reviewer
- **Verify:** bash — xcodebuild test
- **Files to modify:** `GameViewModelTests.swift`, `LowDopamineLabyrinth.xcodeproj/project.pbxproj`
- **Files to read:** `GameViewModel.swift`, `LabyrinthLoader.swift`, `UserPreferences.swift`

### Final Wave

#### Task 12: Pre-deploy QA
- **Description:** Acceptance testing: run all tests, verify all acceptance criteria from user-spec and tech-spec. Verify content files (60 JSONs, no lv2/lv4, correct difficulty values). Build and visual check in simulator.
- **Skill:** pre-deploy-qa
- **Reviewers:** none
