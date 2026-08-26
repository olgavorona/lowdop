import XCTest
@testable import LowDopScribble

final class GameViewModelTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        let keys = ["ttsEnabled", "hasCompletedOnboarding", "ttsDefaultSet", "completedLabyrinths"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
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
                    items: nil,
                    avoidItems: nil
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

    private func makeVM() -> GameViewModel {
        GameViewModel(preferences: UserPreferences(), progressTracker: ProgressTracker())
    }

    // MARK: - Navigation Tests

    func testNextLabyrinthIncrementsIndex() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.currentIndex = 0

        vm.nextLabyrinth()

        XCTAssertEqual(vm.currentIndex, 1)
    }

    func testNextLabyrinthDoesNotExceedBounds() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 3)
        vm.currentIndex = 2

        vm.nextLabyrinth()

        XCTAssertEqual(vm.currentIndex, 2, "Should not advance past last labyrinth")
    }

    func testPreviousLabyrinthDecrementsIndex() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.currentIndex = 3

        vm.previousLabyrinth()

        XCTAssertEqual(vm.currentIndex, 2)
    }

    func testPreviousLabyrinthDoesNotGoBelowZero() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.currentIndex = 0

        vm.previousLabyrinth()

        XCTAssertEqual(vm.currentIndex, 0, "Should not go below 0")
    }

    func testSelectLabyrinthSetsIndexAndPlaying() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 5)

        vm.selectLabyrinth(vm.labyrinths[3])

        XCTAssertEqual(vm.currentIndex, 3)
        XCTAssertTrue(vm.isPlaying)
    }

    func testCloseGameStopsPlaying() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.selectLabyrinth(vm.labyrinths[0])

        vm.closeGame()

        XCTAssertFalse(vm.isPlaying)
    }

    func testNextLabyrinthDoesNotDismissFullScreenCover() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.selectLabyrinth(vm.labyrinths[0])
        XCTAssertTrue(vm.isPlaying)

        vm.nextLabyrinth()

        XCTAssertTrue(vm.isPlaying, "Next should not dismiss the game view")
        XCTAssertEqual(vm.currentIndex, 1)
    }

    func testPreviousLabyrinthDoesNotDismissFullScreenCover() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 5)
        vm.selectLabyrinth(vm.labyrinths[2])
        XCTAssertTrue(vm.isPlaying)

        vm.previousLabyrinth()

        XCTAssertTrue(vm.isPlaying, "Previous should not dismiss the game view")
        XCTAssertEqual(vm.currentIndex, 1)
    }

    func testCurrentLabyrinthReflectsIndex() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 5)

        vm.currentIndex = 2
        XCTAssertEqual(vm.currentLabyrinth?.id, "lab_2")

        vm.nextLabyrinth()
        XCTAssertEqual(vm.currentLabyrinth?.id, "lab_3")
    }

    func testCompleteCurrentLabyrinthTracksProgress() {
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: UserPreferences(), progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 3)
        vm.currentIndex = 1

        vm.completeCurrentLabyrinth()

        XCTAssertTrue(progress.isCompleted("lab_1"))
    }

    func testNavigationSequenceCompletionThenNext() {
        let progress = ProgressTracker()
        let vm = GameViewModel(preferences: UserPreferences(), progressTracker: progress)
        vm.labyrinths = makeSampleLabyrinths(count: 5)

        vm.selectLabyrinth(vm.labyrinths[0])
        XCTAssertTrue(vm.isPlaying)
        XCTAssertEqual(vm.currentIndex, 0)

        vm.completeCurrentLabyrinth()
        XCTAssertTrue(progress.isCompleted("lab_0"))

        vm.nextLabyrinth()
        XCTAssertEqual(vm.currentIndex, 1)
        XCTAssertTrue(vm.isPlaying, "Should still be playing after advancing")
        XCTAssertEqual(vm.currentLabyrinth?.id, "lab_1")
    }

    func testIsLastLabyrinthInPackTracksFinalIndex() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 3)

        vm.currentIndex = 1
        XCTAssertFalse(vm.isLastLabyrinthInPack)

        vm.currentIndex = 2
        XCTAssertTrue(vm.isLastLabyrinthInPack)
    }

    func testSelectLabyrinthDoesNotSetPlayingWhenNotFound() {
        let vm = makeVM()
        vm.labyrinths = makeSampleLabyrinths(count: 3)

        let fake = Labyrinth(
            id: "nonexistent_999",
            ageRange: nil, difficulty: "easy", theme: "ocean",
            title: "Fake", storySetup: "S", instruction: "I", ttsInstruction: "T",
            characterStart: LabyrinthCharacter(type: "crab", description: "D", position: "left", name: nil, imageAsset: nil),
            characterEnd: LabyrinthCharacter(type: "fish", description: "F", position: "right", name: nil, imageAsset: nil),
            educationalQuestion: "", funFact: "", completionMessage: "",
            pathData: PathData(
                svgPath: "", solutionPath: "", width: 30, complexity: "easy", mazeType: "grid",
                startPoint: PointData(x: 0, y: 0), endPoint: PointData(x: 100, y: 100),
                segments: [], canvasWidth: 300, canvasHeight: 300,
                controlPoints: nil, items: nil, avoidItems: nil
            ),
            visualTheme: VisualTheme(backgroundColor: "#000", decorativeElements: []),
            location: nil, audioInstruction: nil, audioCompletion: nil, itemRule: nil, itemEmoji: nil
        )

        vm.selectLabyrinth(fake)
        XCTAssertFalse(vm.isPlaying, "Should not start playing when labyrinth is not in the list")
    }

    // MARK: - Progress Tests

    func testCompletedCountReflectsProgress() {
        let progress = ProgressTracker()
        let labyrinths = makeSampleLabyrinths(count: 5)

        XCTAssertEqual(progress.completedCount(in: labyrinths), 0)

        progress.markCompleted(labyrinths[0].id)
        progress.markCompleted(labyrinths[2].id)

        XCTAssertEqual(progress.completedCount(in: labyrinths), 2)
    }

    func testCompletedStoryCountCountsStoryOnceWhenAnyDifficultyCompleted() {
        let progress = ProgressTracker()
        let stories = [
            StoryInfo(number: 1, title: "Story 1", location: "reef", characterEnd: "finn",
                      isFree: true, isAdventure: false,
                      labyrinthIds: ["denny_001_easy", "denny_001_medium", "denny_001_hard"]),
            StoryInfo(number: 2, title: "Story 2", location: "reef", characterEnd: "pearl",
                      isFree: true, isAdventure: false,
                      labyrinthIds: ["denny_002_easy", "denny_002_medium", "denny_002_hard"])
        ]

        progress.markCompleted("denny_001_medium")
        XCTAssertEqual(progress.completedStoryCount(in: stories), 1)
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
                items: items,
                avoidItems: nil
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
