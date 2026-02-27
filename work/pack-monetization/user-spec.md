---
created: 2026-02-26
status: approved
type: feature
size: L
---

# User Spec: Pack Monetization

## What we're building

Replace the subscription model (monthly/yearly/lifetime) with a one-time pack purchase system. Reduce difficulty levels from 5 to 3 (easy/medium/hard). Add a new pack picker (bookshelf) screen between the difficulty picker and the maze grid. Each pack costs $9.99 as a one-time purchase, with 3 stories free per pack.

## Why

Subscription fatigue — parents resist recurring charges for a kids app. Selling content as "packs" (like books you buy once and own forever) is a better fit for the audience and the content model. This also simplifies the pricing to a single clear offer per pack.

## How it should work

### New user flow
1. User opens app → Onboarding: pick difficulty (3 cards: easy/medium/hard)
2. After picking → Pack picker screen (bookshelf): shows available packs as book-style cards
3. User taps a pack → Grid screen: shows all stories in that pack at the selected difficulty
4. Stories 1-3 are fully playable (free). Stories 4-20 show a lock icon.
5. Tapping a locked story → parental gate → paywall ($9.99 one-time purchase for the pack)
6. After purchase → all stories in the pack unlock. Grid refreshes to show unlocked state.

### Gameplay flow (unchanged)
7. User taps an unlocked story → maze loads → draw path to solve
8. Complete all 3 difficulty levels of a story → story complete celebration → back to bookshelf
9. "Next" after the last level of a story returns to the bookshelf (not to the next story)

### Pack picker screen
- Always shown (even with 1 pack), to establish UI pattern for future packs
- Shows pack card(s) in a bookshelf-style layout
- Each card shows: pack title, cover art/theme, completion progress
- Tapping a pack enters the grid regardless of purchase status

## Acceptance criteria

- [ ] Onboarding shows 3 difficulty cards (easy/medium/hard) instead of 5
- [ ] New pack picker screen appears after difficulty selection
- [ ] Pack picker always displays even with a single pack
- [ ] Grid shows all 20 stories for the selected pack at the selected difficulty
- [ ] Stories 1-3 are fully playable without purchase (all 3 difficulty levels)
- [ ] Stories 4-20 show lock icon when pack is not purchased
- [ ] Tapping a locked story triggers parental gate → paywall
- [ ] Paywall shows single product: $9.99 one-time purchase
- [ ] After purchase, all stories in the pack unlock immediately
- [ ] Purchase persists across app restarts (StoreKit 2 non-consumable)
- [ ] Restore Purchases works correctly
- [ ] Completing all 3 levels of a story shows story-complete celebration
- [ ] After story-complete celebration, user returns to bookshelf
- [ ] Old subscription product IDs removed (no existing subscribers to migrate)
- [ ] 40 maze JSON files deleted (lv2 and lv4 variants)
- [ ] Remaining 60 maze files have correct difficulty names (easy/medium/hard)
- [ ] difficulty_samples.json has 3 entries (easy/medium/hard)
- [ ] App builds and runs without errors

## Constraints

- iOS 15.0+ deployment target
- iPad landscape orientation only
- Zero external dependencies (Apple frameworks only)
- StoreKit 2 for IAP (client-side, no backend)
- COPPA compliant: parental gate before any purchase
- No existing subscribers — clean break, no migration needed
- File naming: rename lv1→easy, lv3→medium, lv5→hard for clarity

## Risks

- **Risk 1:** App Store review may question the removal of subscription options. **Mitigation:** The app hasn't been released yet, so there are no existing subscribers. One-time purchase is a simpler, cleaner model.
- **Risk 2:** Future packs require significant content generation (20 stories x 3 levels each). **Mitigation:** Out of scope for this feature. Content pipeline already exists (generator.py). Pack structure is designed to accommodate new packs when content is ready.

## Technical decisions

- We decided to use a non-consumable IAP (not subscription) because the "buy once, own forever" model matches the pack/book metaphor.
- We decided to rename difficulty levels in both code and JSON files (beginner→easy, expert→hard) because the app hasn't been released and there's no migration concern.
- We decided to rename maze files (lv1→easy, lv3→medium, lv5→hard) for the same reason.
- We decided to keep the grid layout unchanged — packs are selected on the bookshelf, grid shows stories for that pack.
- We decided to always show the pack picker screen even with 1 pack, to establish the pattern for future content.
- We decided to remove the daily-limit free play model entirely (no more "3 free + 1/day"). Instead: 3 stories free per pack, rest locked.

## Testing

**Unit tests:** Always done. Pack data model, difficulty enum, story locking logic, purchase state.

**Integration tests:** Yes — StoreKit 2 purchase flow using Xcode StoreKit testing configuration. Verify purchase → unlock → persist cycle.

**E2E tests:** No — visual verification in simulator is sufficient for UI changes. No automated E2E framework in the project.

## How to verify

### Agent verifies

| Step | Tool | Expected result |
|------|------|-----------------|
| 1. Build the app | xcodebuild | BUILD SUCCEEDED |
| 2. Run unit tests | xcodebuild test | All tests pass |
| 3. Verify 60 maze JSONs exist | Glob/Bash | 60 files matching denny_*_{easy,medium,hard}.json |
| 4. Verify no lv2/lv4 files remain | Glob/Bash | 0 files matching denny_*_lv{2,4}.json |
| 5. Verify difficulty field in JSONs | Grep | Only "easy", "medium", "hard" values |
| 6. Verify manifest.json has 60 entries | Read | total: 60 |

### User verifies

- Launch in simulator → onboarding shows 3 difficulty cards → pick one → pack picker shows 1 pack → tap it → grid shows 20 stories
- Stories 1-3 playable, stories 4-20 show locks
- Tap locked story → parental gate → paywall with $9.99 price
- Complete 3 levels of a story → celebration → back to bookshelf
- Visually confirm all screens look correct (no clipping, overflow, or sizing issues)
