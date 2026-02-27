# Pack Monetization - Decisions Log

## Task 1: Content file changes

Restructured maze content from 5-level (lv1-lv5) to 3-level (easy/medium/hard) system. Deleted 40 intermediate-difficulty files (lv2/lv4), renamed 60 remaining files, updated all JSON fields (id, difficulty, path_data.complexity, removed age_range), rewrote manifest.json with pack structure (60 entries, packs array with ocean_adventures, story field per entry), and reduced difficulty_samples.json from 5 keys to 3. No deviations from spec.

## Task 4: Labyrinth model + StoryInfo + LabyrinthLoader

Added StoryInfo model, PackInfo struct, updated LabyrinthManifest with packs array, added story field to ManifestEntry, and added storyNumber/levelName computed properties to Labyrinth. Extended LabyrinthLoader with loadStories(), loadForStory(storyNumber:difficulty:), and loadAllForStory(storyNumber:) methods. Also fixed pbxproj file references (lv1-lv5 to easy/medium/hard) left broken by Task 1, fixed OnboardingView/LabyrinthGridView references to removed DifficultyLevel.beginner/expert cases from Task 2, and restored missing UserPreferences paywall methods (recordPlay, canPlayToday, freeLabyrinthsRemaining) that Task 2 had removed. All tests pass including new StoryInfo and LabyrinthModel tests.

## Task 11: Integration cleanup

Verified pbxproj was already correct (60 maze files with easy/medium/hard names, no lv2/lv4 references, BookshelfView.swift present, all test files referenced). Removed dead free-play tracking code from UserPreferences (recordPlay, canPlayToday, freeLabyrinthsRemaining, totalFreeLabyrinthsPlayed, dailyLabyrinthsPlayed, lastPlayedTimestamp), removed compatibility shim from SubscriptionManager (products computed property), cleaned up GameViewModelTests tearDown and removed testCompleteCurrentLabyrinthDoesNotCallRecordPlay which referenced deleted APIs. Build and all tests pass. No deviations from spec -- most pbxproj and test work was already done by prior tasks (4, 8, 9).
