# Pack Monetization Feature -- Code Research

## Executive Summary

The pack-monetization feature replaces subscription tiers with a single $10 one-time purchase, reduces 5 difficulty levels to 3, changes the number of stories from 10+10 to 20 (stories 1-3 free, 4-20 paid), and introduces a "bookshelf" pack screen between onboarding and the levels grid. This document catalogs every file that needs changes, what specifically must change, and the tricky parts.

---

## A. Files That Need Changes

### 1. SubscriptionManager.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Services/SubscriptionManager.swift`

**Current behavior:**
- Manages 3 product IDs: `labyrinth_unlimited_monthly`, `labyrinth_unlimited_yearly`, `labyrinth_unlimited_lifetime`
- `isPremium: Bool` -- set to true if user has any active entitlement
- `products: [Product]` -- loaded from App Store, sorted by price
- `checkEntitlements()` iterates `Transaction.currentEntitlements` checking all 3 product IDs
- `listenForTransactions()` watches for updates
- Supports `restorePurchases()` via `AppStore.sync()`

**What needs to change:**
- Replace `productIds` array with a single product ID, e.g. `"labyrinth_pack_full"` (non-consumable, $9.99)
- Remove old subscription product IDs entirely
- Rename `isPremium` to `hasPurchasedPack` (or keep `isPremium` for backward compatibility -- decision needed)
- Simplify `loadProducts()` -- only one product to load
- Remove auto-renewal logic references (the product is non-consumable, not a subscription)
- `checkEntitlements()` only needs to check for the single non-consumable
- Consider adding a convenience `var product: Product?` (single product instead of array)

**Tricky parts:**
- **Migration for existing subscribers**: If any users already purchased a subscription, their entitlement must still be honored. `checkEntitlements()` should check BOTH old subscription IDs and the new pack ID for backward compatibility, OR map old entitlements to the new `isPremium` flag. Since the app isn't launched yet (no existing subscribers), this may not be needed -- confirm before implementing.
- StoreKit 2 handles non-consumables the same way through `Transaction.currentEntitlements`, so the core purchase/verify flow stays the same.

**Lines of interest:**
- Lines 7-11: product IDs array
- Lines 24-31: `loadProducts()`
- Lines 34-52: `purchase()` -- works for non-consumable too, no changes needed
- Lines 61-72: `checkEntitlements()` -- simplify to single ID

---

### 2. PaywallView.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Views/PaywallView.swift`

**Current behavior:**
- 2-column landscape layout: left = hero image + benefits + legal links, right = plan cards + CTA
- `ForEach(subscriptionManager.products)` renders a `PlanCard` per product
- Radio-select UI for choosing between monthly/yearly/lifetime
- `selectedProductID` defaults to yearly
- CTA text varies: "Start Free Trial" / "Buy Once" / "Subscribe"
- Parental gate required before purchase
- "Maybe Later" dismiss button
- "Restore Purchases" + Terms + Privacy links in footer
- Auto-renewal disclaimer text

**What needs to change:**
- **Completely simplify the right column**: Remove `ForEach` product cards, radio selection, plan picker
- Single product display: show pack price ($9.99), "Buy once, play forever" messaging
- CTA becomes just "Buy Now" or "Unlock All Stories -- $9.99"
- Remove auto-renewal disclaimer text (line 52-56)
- Remove `PlanCard` struct entirely (lines 192-272)
- Remove `selectedProductID` state, `yearlyID`, `lifetimeID` constants
- Remove `ctaText` computed property (replace with static text)
- Update benefits list: change "100 mazes across 20 ocean stories" to "60 mazes across 20 stories" (20 stories x 3 difficulty levels = 60, minus 9 free = 51 paid, but display total)
- `executePurchase()` simplifies to just purchasing the single product
- Keep: Restore Purchases, Terms, Privacy, parental gate, Maybe Later, DEBUG skip button

**Tricky parts:**
- The paywall is used from 3 places: LabyrinthGridView (banner + grid tap), LabyrinthListView (next button). All callers use `.sheet(isPresented: $showPaywall)` with `PaywallView(onSkip:)`. The interface can stay the same.
- Layout may need rethinking since there is only 1 product -- the 2-column layout may look sparse. Consider a single-column centered layout.

---

### 3. ContentView.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/ContentView.swift`

**Current behavior:**
- Simple router: `hasCompletedOnboarding` ? `LabyrinthGridView()` : `OnboardingView()`
- Only 2 states

**What needs to change:**
- Add a 3rd state: after onboarding, show the new **BookshelfView** (pack/story selection screen)
- New navigation flow: `OnboardingView` -> `BookshelfView` -> `LabyrinthGridView`
- Need a new UserPreferences property like `selectedStoryPack: String?` or `selectedStoryId: Int?` to track which story/pack the user selected on the bookshelf
- After onboarding completes, `hasCompletedOnboarding = true` takes user to BookshelfView
- Tapping a story on BookshelfView loads that story's mazes and goes to LabyrinthGridView

**Tricky parts:**
- The `LabyrinthGridView` currently loads ALL mazes for the selected difficulty. With the new flow, it needs to load mazes for a SPECIFIC STORY at the selected difficulty (e.g., story 001 has 3 mazes: lv1, lv3, lv5).
- Need to decide: does BookshelfView replace LabyrinthGridView as the "home" screen, or is LabyrinthGridView nested per-story? The grid currently shows all 10 mazes for one difficulty; with packs it would show 3 mazes for one story at different difficulties.

---

### 4. OnboardingView.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Views/OnboardingView.swift`

**Current behavior:**
- Shows 5 `DifficultyCard` views in an HStack (beginner/easy/medium/hard/expert)
- Each card has: mini maze preview (from `difficulty_samples.json`), level name, difficulty dots (1-5)
- Tapping sets `preferences.difficultyLevel` and `hasCompletedOnboarding = true`
- `loadSamplePath(for:)` reads `difficulty_samples.json`
- Privacy Policy link at bottom

**What needs to change:**
- Reduce from 5 cards to 3 cards: Easy (was beginner/lv1), Medium (was medium/lv3), Hard (was expert/lv5)
- Update `levelColors` dictionary to only have 3 entries
- Difficulty dots: change from 5 to 3
- `DifficultyCard.levelNumber` mapping: Easy=1, Medium=2, Hard=3
- On tap, navigate to BookshelfView instead of directly to grid

**Tricky parts:**
- The `DifficultyCard` is also reused by `DifficultyPickerSheet` in LabyrinthGridView (the difficulty-change sheet behind parental gate). Both must be updated to 3 levels.
- Maze preview paths in `difficulty_samples.json` need to map to the 3 kept levels only.

---

### 5. LabyrinthGridView.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Views/LabyrinthGridView.swift`

**Current behavior:**
- Shows 10 `LabyrinthCard` views in a 4-column `LazyVGrid`
- Sequential unlock: card N is unlocked if card N-1 is completed
- Difficulty badge in header (tappable, behind parental gate) to change difficulty
- Progress bar showing completed/total
- Free plays banner with "Unlock All" button
- "See you tomorrow!" banner when daily limit reached
- Paywall shown when tapping locked-by-limit labyrinth
- `LabyrinthCard` shows: character thumbnail, title, completion star, item emoji badge, lock icon
- `onAppear` calls `gameViewModel.loadLabyrinths()`
- Full-screen game presented via `$gameViewModel.isPlaying`

**What needs to change:**
- **Lock logic overhaul**: Instead of "all unlocked, time-gated," change to "stories 1-3 free, stories 4-20 require pack purchase"
  - Currently lock = sequential (previous not completed)
  - New: story-level locking. Within a story, mazes may still be sequential. But the STORY itself is locked if story number > 3 and user hasn't purchased pack.
  - The grid now shows 3 mazes per story (easy/medium/hard for one story), not 10 stories at one difficulty
- **Remove free plays banner** (lines 98-153): No more "3 free + 1/day" model. Replace with "stories 4-20 locked" UI
- **Remove daily limit logic**: No more `freeLabyrinthsRemaining`, `canPlayToday` checks
- **Add "Buy Pack" CTA** for locked stories (simpler paywall trigger)
- The grid may show 3 cards (one per difficulty level) for the selected story, or the BookshelfView handles story selection and the grid shows the 3 difficulty variants
- Consider: if BookshelfView is the story selector, LabyrinthGridView becomes a "story detail" view showing 3 maze cards

**Tricky parts:**
- The `DifficultyPickerSheet` (lines 333-384) is embedded here and uses all 5 difficulty levels. Must update to 3.
- The `LabyrinthCard` (lines 249-331) is reusable but currently doesn't distinguish between "locked because sequential" vs "locked because paywall."
- Navigation flow is fundamentally changing: currently grid is the home screen, now BookshelfView is home.

---

### 6. GameViewModel.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/ViewModels/GameViewModel.swift`

**Current behavior:**
- `labyrinths: [Labyrinth]` -- all mazes for current difficulty (loaded by LabyrinthLoader)
- `currentIndex: Int` -- index within the array
- `isPlaying: Bool` -- controls fullScreenCover
- `loadLabyrinths()` calls `LabyrinthLoader.shared.loadForDifficulty(preferences.difficultyLevel)`
- `canProceed()` delegates to `preferences.canPlayToday(isPremium:)`
- `completeCurrentLabyrinth()` calls `progressTracker.markCompleted()` + `preferences.recordPlay()`
- `selectLabyrinth()` finds index and sets `isPlaying = true`

**What needs to change:**
- `loadLabyrinths()` needs a new method: load by story + difficulty OR load by story with all 3 difficulty levels
  - Option A: `loadForStory(_ storyNumber: Int)` -- loads 3 mazes (easy/medium/hard) for one story
  - Option B: keep `loadForDifficulty()` but filter to a specific story
- Remove `canProceed()` free-play gating -- replace with pack-purchase check
- New method: `isStoryLocked(_ storyNumber: Int) -> Bool` -- returns true if story > 3 and no pack purchased
- `completeCurrentLabyrinth()` can remove `preferences.recordPlay()` (no more daily tracking)
- Keep: `selectLabyrinth`, `nextLabyrinth`, `previousLabyrinth`, `closeGame`, `isPlaying`

**Tricky parts:**
- Currently `labyrinths` holds 10+ mazes for one difficulty. With the new model, it would hold 3 mazes for one story. The `currentIndex` / next / previous logic still works but the array is smaller.
- `isPremium` currently wraps `subscriptionManager.isPremium`. This can stay as-is but semantics change to "has purchased pack."

---

### 7. UserPreferences.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Models/UserPreferences.swift`

**Current behavior:**
- `DifficultyLevel` enum: `beginner, easy, medium, hard, expert` (5 cases, `CaseIterable`)
- Each level has `displayName` (capitalized rawValue) and `pathTolerance` (25/22/18/15/12)
- `difficultyLevel` stored in UserDefaults
- Free play tracking: `totalFreeLabyrinthsPlayed`, `dailyLabyrinthsPlayed`, `lastPlayedTimestamp`
- `canPlayToday(isPremium:)` -- 3 free + 1/day logic
- `recordPlay()` -- increments counters
- `freeLabyrinthsRemaining(isPremium:)` -- for UI display

**What needs to change:**
- **DifficultyLevel enum**: Reduce to 3 cases: `easy, medium, hard`
  - `easy` = old `beginner` (lv1): grid [3,4], tolerance 25
  - `medium` = old `medium` (lv3): grid [6,8], tolerance 18
  - `hard` = old `expert` (lv5): grid [10,13], tolerance 12
  - Update `pathTolerance` to map to the 3 kept levels
  - The raw values are used as keys for loading mazes. If we keep rawValues as "easy"/"medium"/"hard", the maze JSONs' `difficulty` field must match. But current lv1 files have `difficulty: "beginner"` and lv5 files have `difficulty: "expert"`. Either:
    - (a) Rename the `difficulty` field in all kept JSON files, OR
    - (b) Map enum rawValues to the old difficulty strings internally
- **Remove free play tracking**: Delete `totalFreeLabyrinthsPlayed`, `dailyLabyrinthsPlayed`, `lastPlayedTimestamp`
- **Remove `canPlayToday()`, `recordPlay()`, `freeLabyrinthsRemaining()`** -- no longer needed
- **Migration**: Users who already set `difficultyLevel = "beginner"` or `"expert"` in UserDefaults need graceful fallback. The `init()` uses `DifficultyLevel(rawValue:)` which will return nil for removed cases. Default to `.easy`.
- **Add**: `selectedStory: Int?` -- which story the user is currently viewing (for BookshelfView -> Grid flow)

**Tricky parts:**
- `DifficultyLevel` is used across many files: OnboardingView, LabyrinthGridView (DifficultyPickerSheet), LabyrinthLoader, GameViewModel. All must be updated.
- The init default is `.beginner` which won't exist. Must change to `.easy`.
- The `pathTolerance` computed property feeds into `DrawingValidator` via `preferences.pathTolerance`. The mapping must remain correct.

---

### 8. LabyrinthLoader.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Services/LabyrinthLoader.swift`

**Current behavior:**
- Singleton: `LabyrinthLoader.shared`
- `loadManifest()` reads `manifest.json` -> `LabyrinthManifest`
- `loadLabyrinth(id:)` reads individual JSON file by ID
- `loadAll()` loads all labyrinths from manifest (cached)
- `loadForDifficulty(_ level:)` filters by `difficulty` field, then interleaves normal + adventure mazes

**What needs to change:**
- **Add `loadForStory(_ storyNumber: Int) -> [Labyrinth]`**: Load all 3 difficulty variants for one story
  - e.g., story 1 -> `[denny_001_lv1, denny_001_lv3, denny_001_lv5]`
  - Must know which level numbers to load (lv1, lv3, lv5 only after pruning lv2/lv4)
- **Update `loadForDifficulty()`** or remove it: May no longer be the primary loading method
- **Handle difficulty name mapping**: The kept JSON files have `difficulty: "beginner"` (lv1), `"medium"` (lv3), `"expert"` (lv5). The new enum will use `"easy"`, `"medium"`, `"hard"`. Either:
  - Rename difficulty in all JSON files (preferred, cleaner)
  - Add mapping logic in loader
- **Add story listing**: `loadStories() -> [StoryInfo]` to provide data for the BookshelfView
  - Each story has: number, title, location, character, whether free or paid
  - Can derive from manifest entries: group by `base_id` (story number)
- **Cache invalidation**: `cachedLabyrinths` caches ALL loaded mazes. With fewer total mazes (60 vs 100), this is fine.
- Interleave logic (normal + adventure) may need revisiting based on how BookshelfView groups stories

**Tricky parts:**
- The manifest currently has 100 entries. After removing lv2/lv4, it will have 60 entries.
- Story numbering: stories 001-010 are "normal" (navigate to character), stories 011-020 are "adventure" (collect items). The bookshelf should present all 20 as a unified list.
- Audio files are per-story (not per-level), so audio references in remaining JSONs are unaffected by level deletion.

---

### 9. Labyrinth.swift (Model)
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Models/Labyrinth.swift`

**Current behavior:**
- `Labyrinth` struct: `Codable, Identifiable` with all maze properties
- `LabyrinthManifest` struct with `total: Int` and `labyrinths: [ManifestEntry]`
- `ManifestEntry`: `id, difficulty, theme, title, location`
- Helper types: `PathData`, `SegmentData`, `PointData`, `VisualTheme`, `LabyrinthCharacter`, `ItemData`

**What needs to change:**
- **Add `storyNumber: Int` computed property** (parse from ID: `denny_001_lv1` -> 1)
- **Add `levelNumber: Int` computed property** (parse from ID: `denny_001_lv1` -> 1)
- Consider adding `ManifestEntry.storyNumber` for grouping on the bookshelf
- The `difficulty` field in JSON files needs to be updated if we rename beginner->easy and expert->hard
- `ageRange` field is already optional (`String?`) and unused -- can eventually remove

**Tricky parts:**
- The `difficulty: String` field in `Labyrinth` stores the raw difficulty name from JSON. If we rename difficulties in JSON, this is straightforward. If not, we need mapping elsewhere.
- Model changes affect test files that construct `Labyrinth` instances directly.

---

### 10. LabyrinthListView.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Views/LabyrinthListView.swift`

**Current behavior:**
- Full-screen game container presented via `isPlaying`
- Renders `LabyrinthGameView` + `NavigationControls` + `CompletionView`
- `attemptNext()` checks `canProceed()` -> shows paywall if blocked
- Paywall dismiss handler: if purchased/skipped, advance; if "Maybe Later", close game
- `updateVM()` creates new `LabyrinthViewModel` when navigating

**What needs to change:**
- `attemptNext()` logic: Instead of free-play gating, check if the NEXT maze's story is locked (story > 3 and no pack)
- The paywall integration stays but trigger condition changes
- Navigation within a story's 3 mazes (easy->medium->hard) should be seamless
- Navigation ACROSS stories may need to return to BookshelfView or show "story complete" prompt

**Tricky parts:**
- With only 3 mazes per story, "Next Labyrinth" at index 2 (the last difficulty) needs special handling: return to bookshelf? Auto-advance to next story?
- The completion flow (complete -> next) must respect story boundaries and pack ownership.

---

### 11. LowDopamineLabyrinthApp.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/LowDopamineLabyrinthApp.swift`

**Current behavior:**
- Creates `@StateObject` instances: preferences, subscriptionManager, progressTracker, ttsService
- `RootView` creates `GameViewModel` and injects all as `@EnvironmentObject`

**What needs to change:**
- Minimal changes. The `SubscriptionManager` name/interface may evolve but the injection pattern stays the same.
- If a new "PackManager" or "StoreManager" replaces SubscriptionManager, update the `@StateObject` and environment injection here.

---

### 12. CompletionView.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Views/CompletionView.swift`

**Current behavior:**
- Shows character celebration, completion message, item stats, educational section, "Next Labyrinth" button, "Try Again" button

**What needs to change:**
- Minor: "Next Labyrinth" text may need to change to "Next Level" within a story, or "Back to Stories" on the last level of a story
- The `onNext` callback is handled by LabyrinthListView which manages navigation

---

### 13. ProgressTracker.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Services/ProgressTracker.swift`

**Current behavior:**
- Tracks completed labyrinth IDs in UserDefaults
- `completedIds: Set<String>`
- `markCompleted()`, `isCompleted()`, `completedCount()`

**What needs to change:**
- Mostly unchanged. IDs like `denny_001_lv1` will still be tracked.
- Remove any completed IDs for lv2/lv4 mazes from existing users' data (migration).
- May want to add: `completedCountForStory(_ storyNumber: Int, in: [Labyrinth]) -> Int`
- May want: `isStoryComplete(_ storyNumber: Int, in: [Labyrinth]) -> Bool`

---

### 14. Test Files

**GameViewModelTests.swift** (`/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinthTests/GameViewModelTests.swift`):
- Heavy testing of free-play model: `canProceed`, `recordPlay`, daily limits, `freeLabyrinthsRemaining`
- Tests construct `Labyrinth` instances with `difficulty: "easy"` -- will need to match new enum values
- **22+ test methods** that reference the free-play model -- most will need rewriting or removal
- Tests for sequential unlock logic still apply
- Tests for `selectLabyrinth`, navigation, `isPremium` still apply with minor adjustments

---

### 15. Analytics.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Services/Analytics.swift`

**What needs to change:**
- No code changes needed, but analytics event names referenced across the app will change:
  - `Paywall.shown` trigger reasons change (no more "banner" trigger from daily limit)
  - `Grid.difficultyChanged` still relevant
  - New events needed: `Bookshelf.storySelected`, `Bookshelf.packPurchased`, etc.

---

### 16. ParentalGateView.swift
**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Views/ParentalGateView.swift`

**What needs to change:**
- No changes needed. Still guards purchase actions and settings access.

---

## B. Content Changes Needed

### Maze JSON Files to DELETE (40 files)

All `_lv2` files (20 files -- difficulty "easy" in current naming):
```
denny_001_lv2.json through denny_020_lv2.json
```

All `_lv4` files (20 files -- difficulty "hard" in current naming):
```
denny_001_lv4.json through denny_020_lv4.json
```

### Maze JSON Files to KEEP (60 files)

Rename difficulty field inside each:
- `_lv1` files (20): `"difficulty": "beginner"` -> `"difficulty": "easy"`
- `_lv3` files (20): `"difficulty": "medium"` -> stays `"difficulty": "medium"`
- `_lv5` files (20): `"difficulty": "expert"` -> `"difficulty": "hard"`

**Option**: Also rename the files themselves (e.g., `denny_001_lv1.json` -> `denny_001_easy.json`) for clarity. This would require updating manifest.json IDs and all ProgressTracker saved data. Probably NOT worth it to avoid migration headaches -- keep lv1/lv3/lv5 naming.

### manifest.json Changes

**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/manifest.json`

**Current:** 100 entries, `"total": 100`
**New:** 60 entries, `"total": 60`

Changes:
- Remove all entries with `_lv2` and `_lv4` IDs
- Update difficulty values: `"beginner"` -> `"easy"`, `"expert"` -> `"hard"`
- Add story grouping metadata (optional): `"story_number": 1` per entry
- Add `"free": true/false` per entry (stories 1-3 free)

New manifest structure (suggested):
```json
{
  "universe": "denny",
  "total": 60,
  "stories": [
    {
      "number": 1,
      "title": "Denny Finds Mommy Coral",
      "location": "sandy_shore",
      "character_end": "mama_coral",
      "free": true,
      "labyrinths": ["denny_001_lv1", "denny_001_lv3", "denny_001_lv5"]
    },
    ...
  ],
  "labyrinths": [
    {"id": "denny_001_lv1", "difficulty": "easy", "theme": "ocean", "location": "sandy_shore", "title": "Denny Finds Mommy Coral"},
    {"id": "denny_001_lv3", "difficulty": "medium", "theme": "ocean", "location": "sandy_shore", "title": "Denny Finds Mommy Coral"},
    {"id": "denny_001_lv5", "difficulty": "hard", "theme": "ocean", "location": "sandy_shore", "title": "Denny Finds Mommy Coral"},
    ...
  ]
}
```

### difficulty_samples.json Changes

**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/difficulty_samples.json`

**Current:** 5 keys: `beginner, easy, medium, hard, expert`
**New:** 3 keys: `easy, medium, hard`

- `"easy"` = current `"beginner"` SVG path (3x4 grid)
- `"medium"` = current `"medium"` SVG path (6x8 grid) -- unchanged
- `"hard"` = current `"expert"` SVG path (10x13 grid)

### config.yaml Changes

**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/content-generator/config.yaml`

**Current:** 5 difficulty levels (beginner/easy/medium/hard/expert)
**New:** 3 difficulty levels:
```yaml
difficulty_levels:
  easy:
    grid_size: [3, 4]
    path_width: 40
    path_tolerance: 25
    shapes: ["rect"]

  medium:
    grid_size: [6, 8]
    path_width: 30
    path_tolerance: 18
    shapes: ["rect"]

  hard:
    grid_size: [10, 13]
    path_width: 22
    path_tolerance: 12
    shapes: ["rect"]
```

### Audio Files -- NO CHANGES

Audio files are named per-story (e.g., `denny_001_instruction.mp3`), not per-level. All 40 audio files (20 stories x 2 files) stay as-is. The lv1/lv3/lv5 JSON files already reference the same audio filenames.

### Content Generator (generator.py) Changes

**Path:** `/Users/olgavorona/Documents/GitHub/lowdop/content-generator/generator.py`

- `generate_difficulty_variants()` (line 414): `difficulty_names` list goes from 5 to 3
- `ADVENTURE_ITEM_COUNTS` (line 699): Remove beginner/expert entries, keep easy/medium/hard
- `generate_adventure_variants()` (line 740): Same difficulty_names change
- `story_outlines.json`: Remove lv2/lv4 entries, update remaining difficulty names

### Xcode Project File (pbxproj)

The 40 deleted JSON files must be removed from the Xcode project's build phase (Copy Bundle Resources). The pbxproj uses sequential hex IDs (AC2001XX-AC2011XX range per MEMORY.md). Each deleted file has:
- A `PBXBuildFile` entry
- A `PBXFileReference` entry
- A reference in `PBXResourcesBuildPhase`

---

## C. New Files/Models Needed

### 1. BookshelfView.swift (NEW)

**Purpose:** The "pack/bookshelf" screen -- shows all 20 stories as a visual grid/list. First 3 stories unlocked, stories 4-20 locked behind pack purchase.

**Design:**
- Landscape layout (iPad)
- 20 story "book" cards in a scrollable grid
- Each card shows: story title, location name, character thumbnail, completion progress (0/3 to 3/3 stars)
- Stories 1-3: always accessible, shown with full color
- Stories 4-20: shown with lock overlay if pack not purchased; accessible if purchased
- "Buy Full Pack -- $9.99" prominent CTA at top or bottom for non-purchasers
- Difficulty indicator: current selected difficulty shown somewhere (can change via settings)
- Tapping a story navigates to LabyrinthGridView (showing 3 mazes for that story)

**Dependencies:**
- `@EnvironmentObject var subscriptionManager: SubscriptionManager`
- `@EnvironmentObject var preferences: UserPreferences`
- `@EnvironmentObject var progressTracker: ProgressTracker`
- `@EnvironmentObject var gameViewModel: GameViewModel`
- Needs story metadata from `LabyrinthLoader` (story number, title, location, character, free status)

**Data needed:**
- Story list with metadata -- from manifest or computed from LabyrinthLoader
- Per-story completion count (how many of 3 mazes completed)

### 2. StoryInfo Model (NEW, in Labyrinth.swift or separate file)

```swift
struct StoryInfo: Identifiable {
    let number: Int          // 1-20
    let title: String
    let location: String
    let characterEnd: String // image asset name
    let isFree: Bool         // stories 1-3 = true
    let isAdventure: Bool    // stories 11-20 have items
    let labyrinthIds: [String] // e.g. ["denny_001_lv1", "denny_001_lv3", "denny_001_lv5"]

    var id: Int { number }
}
```

### 3. StoryCardView.swift (NEW, or inline in BookshelfView)

Individual story card for the bookshelf grid. Similar to `LabyrinthCard` but story-level.

---

## D. Migration & Backward Compatibility

### UserDefaults Migration
- `difficultyLevel`: Users with "beginner" saved -> map to "easy". Users with "expert" -> map to "hard". Users with "easy"/"hard" (old lv2/lv4) -> map to nearest (easy->easy, hard->hard).
- `completedLabyrinths`: Completed lv2/lv4 IDs become orphaned. Harmless but wasted. Optional cleanup.
- `totalFreeLabyrinthsPlayed`, `dailyLabyrinthsPlayed`, `lastPlayedTimestamp`: Can be removed. Existing values ignored.
- `hasCompletedOnboarding`: Keep. Users who completed onboarding skip it again.

### StoreKit Migration
- If the app has already been submitted with the old subscription product IDs, existing subscribers' entitlements should still work. `checkEntitlements()` should check both old and new IDs.
- If not yet submitted (likely), simply replace all product IDs.

---

## E. Dependency Graph (Implementation Order)

1. **DifficultyLevel enum** (UserPreferences.swift) -- everything depends on this
2. **Content changes** (JSON files, manifest, difficulty_samples) -- independent of code but needed for testing
3. **LabyrinthLoader** -- new story-based loading
4. **Labyrinth model** -- add story/level computed properties
5. **SubscriptionManager** -- single product
6. **GameViewModel** -- story-aware loading and pack-based gating
7. **PaywallView** -- simplified single-product UI
8. **BookshelfView** (NEW) -- story grid
9. **ContentView** -- add bookshelf to navigation
10. **OnboardingView** -- 3 difficulty cards
11. **LabyrinthGridView** -- per-story grid, remove free-play logic
12. **LabyrinthListView** -- update next/previous for story context
13. **Tests** -- rewrite free-play tests, add pack tests
14. **pbxproj** -- remove deleted files, add new files
15. **config.yaml / generator.py** -- content tooling update

---

## F. Summary of Counts

| Metric | Current | New |
|--------|---------|-----|
| Difficulty levels | 5 | 3 |
| Stories | 20 (10 normal + 10 adventure) | 20 (unchanged) |
| Mazes per story | 5 | 3 |
| Total mazes | 100 | 60 |
| Free mazes | 3 total + 1/day | 9 (3 stories x 3 levels) |
| Paid mazes | All (subscription) | 51 (17 stories x 3 levels) |
| IAP products | 3 (monthly/yearly/lifetime) | 1 ($9.99 non-consumable) |
| Audio files | 40 | 40 (unchanged) |
| JSON files to delete | 0 | 40 |
| New Swift files | 0 | 1-2 (BookshelfView, optional StoryCardView) |
| Swift files to modify | 0 | 12-14 |
| Test methods to rewrite | 0 | ~15 |
