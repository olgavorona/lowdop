import XCTest
@testable import LowDopamineLabyrinth

final class GameViewModelTests: XCTestCase {

    private func makeSampleLabyrinths(count: Int) -> [Labyrinth] {
        (0..<count).map { i in
            Labyrinth(
                id: "lab_\(i)",
                ageRange: "3-4",
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
                    controlPoints: nil
                ),
                visualTheme: VisualTheme(backgroundColor: "#4A90E2", decorativeElements: ["stars"]),
                location: "coral_reef",
                audioInstruction: nil,
                audioCompletion: nil
            )
        }
    }

    // MARK: - Navigation Tests

    func testNextLabyrinthIncrementsIndex() {
        let prefs = UserPreferences()
        let sub = SubscriptionManager()
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
}
