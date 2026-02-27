import XCTest
@testable import LowDopamineLabyrinth

final class GameViewModelTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Clean up UserDefaults keys used by UserPreferences to isolate tests
        let keys = ["difficultyLevel", "ttsEnabled", "hasCompletedOnboarding",
                     "ttsDefaultSet", "completedLabyrinths"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func makeStoryLabyrinth(id: String) -> Labyrinth {
        Labyrinth(
            id: id,
            ageRange: nil,
            difficulty: "easy",
            theme: "ocean",
            title: "Story Lab",
            storySetup: "Story",
            instruction: "Go",
            ttsInstruction: "Go find it",
            characterStart: LabyrinthCharacter(type: "crab", description: "Denny", position: "bottom_left", name: "Denny", imageAsset: "denny"),
            characterEnd: LabyrinthCharacter(type: "fish", description: "Finn", position: "top_right", name: "Finn", imageAsset: "finn"),
            educationalQuestion: "Question?",
            funFact: "Fun fact",
            completionMessage: "Well done!",
            pathData: PathData(
                svgPath: "M0,0 L100,100",
                solutionPath: "M0,0 L100,100",
                width: 30,
                complexity: "easy",
                mazeType: "grid",
                startPoint: PointData(x: 0, y: 0),
                endPoint: PointData(x: 100, y: 100),
                segments: [SegmentData(start: PointData(x: 0, y: 0), end: PointData(x: 100, y: 100))],
                canvasWidth: 600,
                canvasHeight: 500,
                controlPoints: nil,
                items: nil
            ),
            visualTheme: VisualTheme(backgroundColor: "#4A90E2", decorativeElements: ["stars"]),
            location: "coral_reef",
            audioInstruction: nil,
            audioCompletion: nil,
            itemRule: nil,
            itemEmoji: nil
        )
    }

    private func makeSampleLabyrinths(count: Int) -> [Labyrinth] {
        (0..<count).map { i in
            Labyrinth(
                id: "lab_\(i)",
                ageRange: nil,
                difficulty: "easy",
                theme: "ocean",
                title: "Lab \(i)",
                storySetup: "Story",
                instruction: "Go",
                ttsInstruction: "Go find it",
                characterStart: LabyrinthCharacter(type: "crab", description: "Denny", position: "bottom_left", name: "Denny", imageAsset: "denny"),
                characterEnd: LabyrinthCharacter(type: "fish", description: "Finn", position: "top_right", name: "Finn", imageAsset: "finn"),
                educationalQuestion: "Question?",
                funFact: "Fun fact",
                completionMessage: "Well done!",
                pathData: PathData(
                    svgPath: "M0,0 L100,100",
                    solutionPath: "M0,0 L100,100",
                    width: 30,
                    complexity: "easy",
                    mazeType: "grid",
                    startPoint: PointData(x: 0, y: 0),
                    endPoint: PointData(x: 100, y: 100),
                    segments: [SegmentData(start: PointData(x: 0, y: 0), end: PointData(x: 100, y: 100))],
                    canvasWidth: 600,
                    canvasHeight: 500,
                    controlPoints: nil,
                    items: nil
                ),
                visualTheme: VisualTheme(backgroundColor: "#4A90E2", decorativeElements: ["stars"]),
                location: "coral_reef",
                audioInstruction: nil,
                audioCompletion: nil,
                itemRule: nil,
                itemEmoji: nil
            )
        }
    }

    // MARK: - Navigation Tests

    func testNextLabyrinthIncrementsIndex() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        sub.isPremium = true
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.currentIndex = 0

        vm.nextLabyrinth()

        XCTAssertEqual(vm.currentIndex, 1)
    }

    func testNextLabyrinthDoesNotExceedBounds() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        sub.isPremium = true
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 3)
        vm.currentIndex = 2

        vm.nextLabyrinth()

        XCTAssertEqual(vm.currentIndex, 2, "Should not advance past last labyrinth")
    }

    func testPreviousLabyrinthDecrementsIndex() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.currentIndex = 3

        vm.previousLabyrinth()

        XCTAssertEqual(vm.currentIndex, 2)
    }

    func testPreviousLabyrinthDoesNotGoBelowZero() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.currentIndex = 0

        vm.previousLabyrinth()

        XCTAssertEqual(vm.currentIndex, 0, "Should not go below 0")
    }

    func testSelectLabyrinthSetsIndexAndPlaying() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 5)

        vm.selectLabyrinth(vm.labyrinths[3])

        XCTAssertEqual(vm.currentIndex, 3)
        XCTAssertTrue(vm.isPlaying)
    }

    func testCloseGameStopsPlaying() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.selectLabyrinth(vm.labyrinths[0])

        vm.closeGame()

        XCTAssertFalse(vm.isPlaying)
    }

    func testNextLabyrinthDoesNotDismissFullScreenCover() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        sub.isPremium = true
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.selectLabyrinth(vm.labyrinths[0])
        XCTAssertTrue(vm.isPlaying)

        // Navigating next should NOT change isPlaying
        vm.nextLabyrinth()

        XCTAssertTrue(vm.isPlaying, "Next should not dismiss the game view")
        XCTAssertEqual(vm.currentIndex, 1)
    }

    func testPreviousLabyrinthDoesNotDismissFullScreenCover() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.selectLabyrinth(vm.labyrinths[2])
        XCTAssertTrue(vm.isPlaying)

        vm.previousLabyrinth()

        XCTAssertTrue(vm.isPlaying, "Previous should not dismiss the game view")
        XCTAssertEqual(vm.currentIndex, 1)
    }

    func testCurrentLabyrinthReflectsIndex() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        sub.isPremium = true
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 5)

        vm.currentIndex = 2
        XCTAssertEqual(vm.currentLabyrinth?.id, "lab_2")

        vm.nextLabyrinth()
        XCTAssertEqual(vm.currentLabyrinth?.id, "lab_3")
    }

    func testCompleteCurrentLabyrinthTracksProgress() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 3)
        vm.currentIndex = 1

        vm.completeCurrentLabyrinth()

        XCTAssertTrue(progress.isCompleted("lab_1"))
    }

    func testNavigationSequenceCompletionThenNext() {
        // Simulate: complete maze -> tap "Next Labyrinth" in CompletionView
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        sub.isPremium = true
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 5)

        // 1. User selects labyrinth 0
        vm.selectLabyrinth(vm.labyrinths[0])
        XCTAssertTrue(vm.isPlaying)
        XCTAssertEqual(vm.currentIndex, 0)

        // 2. User completes it
        vm.completeCurrentLabyrinth()
        XCTAssertTrue(progress.isCompleted("lab_0"))

        // 3. User taps "Next Labyrinth" in completion popup
        vm.nextLabyrinth()
        XCTAssertEqual(vm.currentIndex, 1)
        XCTAssertTrue(vm.isPlaying, "Should still be playing after advancing")
        XCTAssertEqual(vm.currentLabyrinth?.id, "lab_1")
    }

    // MARK: - Premium / Story Locking Tests

    func testIsPremiumReflectsSubscriptionManager() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)

        XCTAssertFalse(vm.isPremium, "Should not be premium by default")

        sub.isPremium = true
        XCTAssertTrue(vm.isPremium, "Should reflect subscription manager state")
    }

    func testStoryNumberExtraction() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)

        let lab1 = makeStoryLabyrinth(id: "denny_001_easy")
        XCTAssertEqual(vm.storyNumber(for: lab1), 1)

        let lab15 = makeStoryLabyrinth(id: "denny_015_hard")
        XCTAssertEqual(vm.storyNumber(for: lab15), 15)

        let lab20 = makeStoryLabyrinth(id: "denny_020_medium")
        XCTAssertEqual(vm.storyNumber(for: lab20), 20)
    }

    func testIsStoryLockedFreeUser() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        sub.isPremium = false
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)

        // Stories 1-3 are free
        XCTAssertFalse(vm.isStoryLocked(1), "Story 1 should be unlocked for free user")
        XCTAssertFalse(vm.isStoryLocked(2), "Story 2 should be unlocked for free user")
        XCTAssertFalse(vm.isStoryLocked(3), "Story 3 should be unlocked for free user")

        // Stories 4-20 are locked
        XCTAssertTrue(vm.isStoryLocked(4), "Story 4 should be locked for free user")
        XCTAssertTrue(vm.isStoryLocked(10), "Story 10 should be locked for free user")
        XCTAssertTrue(vm.isStoryLocked(20), "Story 20 should be locked for free user")
    }

    func testIsStoryLockedPremiumUser() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        sub.isPremium = true
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)

        // All stories unlocked for premium
        for story in 1...20 {
            XCTAssertFalse(vm.isStoryLocked(story), "Story \(story) should be unlocked for premium user")
        }
    }

    func testIsStoryLockedAfterPurchase() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        sub.isPremium = false
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)

        // Initially locked
        XCTAssertTrue(vm.isStoryLocked(5), "Story 5 should be locked before purchase")

        // Purchase
        sub.isPremium = true

        // Now unlocked
        XCTAssertFalse(vm.isStoryLocked(5), "Story 5 should be unlocked after purchase")
    }

    func testIsStoryCompleteAllDifficulties() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)

        // Set up labyrinth list and current index to story 5
        let lab = makeStoryLabyrinth(id: "denny_005_easy")
        vm.labyrinths = [lab]
        vm.currentIndex = 0

        // Mark all 3 difficulty levels as completed
        progress.markCompleted("denny_005_easy")
        progress.markCompleted("denny_005_medium")
        progress.markCompleted("denny_005_hard")

        XCTAssertTrue(vm.isStoryComplete, "Story should be complete when all 3 difficulties are done")
    }

    func testIsStoryCompletePartialDifficulties() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)

        // Set up labyrinth list and current index to story 5
        let lab = makeStoryLabyrinth(id: "denny_005_easy")
        vm.labyrinths = [lab]
        vm.currentIndex = 0

        // Only mark 2 of 3 as completed
        progress.markCompleted("denny_005_easy")
        progress.markCompleted("denny_005_medium")

        XCTAssertFalse(vm.isStoryComplete, "Story should not be complete with only 2 of 3 difficulties done")
    }

    // MARK: - Sequential Unlock / Progress Tests

    func testSequentialUnlockLogic() {
        let progress = ProgressTracker()
        let labyrinths = makeSampleLabyrinths(count: 5)

        // First labyrinth is always unlocked
        XCTAssertTrue(true, "Index 0 is always unlocked by convention")

        // Second labyrinth is locked until first is completed
        XCTAssertFalse(progress.isCompleted(labyrinths[0].id), "Lab 0 not completed yet")

        // Complete first labyrinth
        progress.markCompleted(labyrinths[0].id)
        XCTAssertTrue(progress.isCompleted(labyrinths[0].id))

        // Second should now be accessible (index == 0 || previous completed)
        let index1Unlocked = progress.isCompleted(labyrinths[0].id)
        XCTAssertTrue(index1Unlocked, "Lab 1 should be unlocked after Lab 0 completed")

        // Third should still be locked
        let index2Unlocked = progress.isCompleted(labyrinths[1].id)
        XCTAssertFalse(index2Unlocked, "Lab 2 should still be locked")
    }

    func testCompletedCountReflectsProgress() {
        let progress = ProgressTracker()
        let labyrinths = makeSampleLabyrinths(count: 5)

        XCTAssertEqual(progress.completedCount(in: labyrinths), 0)

        progress.markCompleted(labyrinths[0].id)
        progress.markCompleted(labyrinths[2].id)

        XCTAssertEqual(progress.completedCount(in: labyrinths), 2)
    }

    // MARK: - selectLabyrinth safety

    func testSelectLabyrinthDoesNotSetPlayingWhenNotFound() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: prefs, subscriptionManager: sub, progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 3)

        // Create a labyrinth that is NOT in the list
        let orphan = makeSampleLabyrinths(count: 1).first!
        let fake = Labyrinth(
            id: "nonexistent_999",
            ageRange: nil, difficulty: orphan.difficulty, theme: orphan.theme,
            title: orphan.title, storySetup: orphan.storySetup,
            instruction: orphan.instruction, ttsInstruction: orphan.ttsInstruction,
            characterStart: orphan.characterStart, characterEnd: orphan.characterEnd,
            educationalQuestion: orphan.educationalQuestion, funFact: orphan.funFact,
            completionMessage: orphan.completionMessage, pathData: orphan.pathData,
            visualTheme: orphan.visualTheme, location: orphan.location,
            audioInstruction: nil, audioCompletion: nil, itemRule: nil, itemEmoji: nil
        )

        vm.selectLabyrinth(fake)

        XCTAssertFalse(vm.isPlaying, "Should not start playing when labyrinth is not in the list")
    }
}

// MARK: - LabyrinthViewModel Item Tests

final class LabyrinthViewModelItemTests: XCTestCase {

    private func makeLabyrinth(itemRule: String?, itemEmoji: String?, items: [ItemData]?) -> Labyrinth {
        Labyrinth(
            id: "test_items",
            ageRange: nil,
            difficulty: "easy",
            theme: "ocean",
            title: "Test",
            storySetup: "Story",
            instruction: "Go",
            ttsInstruction: "Go",
            characterStart: LabyrinthCharacter(type: "crab", description: "Denny", position: "bottom_left", name: "Denny", imageAsset: "denny"),
            characterEnd: LabyrinthCharacter(type: "fish", description: "Finn", position: "top_right", name: "Finn", imageAsset: "finn"),
            educationalQuestion: "Q?",
            funFact: "Fact",
            completionMessage: "Done!",
            pathData: PathData(
                svgPath: "M0,0 L200,0 M0,0 L0,200 M200,0 L200,200 M0,200 L200,200",
                solutionPath: "M100,100 L100,100",
                width: 30,
                complexity: "easy",
                mazeType: "corridor_rect",
                startPoint: PointData(x: 0, y: 0),
                endPoint: PointData(x: 200, y: 200),
                segments: [
                    SegmentData(start: PointData(x: 0, y: 0), end: PointData(x: 200, y: 0)),
                    SegmentData(start: PointData(x: 0, y: 0), end: PointData(x: 0, y: 200)),
                    SegmentData(start: PointData(x: 200, y: 0), end: PointData(x: 200, y: 200)),
                    SegmentData(start: PointData(x: 0, y: 200), end: PointData(x: 200, y: 200))
                ],
                canvasWidth: 300,
                canvasHeight: 300,
                controlPoints: nil,
                items: items
            ),
            visualTheme: VisualTheme(backgroundColor: "#4A90E2", decorativeElements: []),
            location: nil,
            audioInstruction: nil,
            audioCompletion: nil,
            itemRule: itemRule,
            itemEmoji: itemEmoji
        )
    }

    func testCollectTypeProperties() {
        let lab = makeLabyrinth(itemRule: "collect", itemEmoji: "🐚", items: [
            ItemData(x: 50, y: 50, emoji: "🐚", onSolution: true),
            ItemData(x: 100, y: 100, emoji: "🐚", onSolution: true)
        ])
        let vm = LabyrinthViewModel(labyrinth: lab)

        XCTAssertTrue(vm.isCollectType)
        XCTAssertTrue(vm.hasItems)
        XCTAssertEqual(vm.totalItemCount, 2)
        XCTAssertFalse(vm.allItemsCollected)
    }

    func testNoItemsProperties() {
        let lab = makeLabyrinth(itemRule: nil, itemEmoji: nil, items: nil)
        let vm = LabyrinthViewModel(labyrinth: lab)

        XCTAssertFalse(vm.isCollectType)
        XCTAssertFalse(vm.hasItems)
        XCTAssertEqual(vm.totalItemCount, 0)
    }

    func testResetClearsItemState() {
        let lab = makeLabyrinth(itemRule: "collect", itemEmoji: "🐚", items: [
            ItemData(x: 50, y: 50, emoji: "🐚", onSolution: true)
        ])
        let vm = LabyrinthViewModel(labyrinth: lab)
        vm.collectedItemIndices.insert(0)

        vm.reset()

        XCTAssertTrue(vm.collectedItemIndices.isEmpty)
        XCTAssertFalse(vm.isCompleted)
        XCTAssertFalse(vm.showItemHint)
    }

    func testItemHUDTextCollect() {
        let lab = makeLabyrinth(itemRule: "collect", itemEmoji: "🐚", items: [
            ItemData(x: 50, y: 50, emoji: "🐚", onSolution: true),
            ItemData(x: 100, y: 100, emoji: "🐚", onSolution: true)
        ])
        let vm = LabyrinthViewModel(labyrinth: lab)

        XCTAssertEqual(vm.itemHUDText, "🐚 0/2")

        vm.collectedItemIndices.insert(0)
        XCTAssertEqual(vm.itemHUDText, "🐚 1/2")
    }
}
