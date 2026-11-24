import XCTest
import AVFoundation
@testable import LowDopamineLabyrinth

final class LabyrinthViewModelTests: XCTestCase {

    private func makeSampleLabyrinth(
        startPoint: PointData = PointData(x: 10, y: 10),
        endPoint: PointData = PointData(x: 290, y: 290),
        segments: [SegmentData]? = nil
    ) -> Labyrinth {
        let defaultSegments = [
            SegmentData(start: PointData(x: 10, y: 10), end: PointData(x: 150, y: 10)),
            SegmentData(start: PointData(x: 150, y: 10), end: PointData(x: 150, y: 150)),
            SegmentData(start: PointData(x: 150, y: 150), end: PointData(x: 290, y: 150)),
            SegmentData(start: PointData(x: 290, y: 150), end: PointData(x: 290, y: 290)),
        ]
        return Labyrinth(
            id: "test_lab",
            ageRange: "3-4",
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
                svgPath: "M10,10 L150,10 L150,150 L290,150 L290,290",
                solutionPath: "M 10 10 L 150 10 L 150 150 L 290 150 L 290 290",
                width: 30,
                complexity: "easy",
                mazeType: "grid",
                startPoint: startPoint,
                endPoint: endPoint,
                segments: segments ?? defaultSegments,
                canvasWidth: 300,
                canvasHeight: 300,
                controlPoints: nil,
                items: nil,
                avoidItems: nil
            ),
            visualTheme: VisualTheme(backgroundColor: "#4A90E2", decorativeElements: []),
            location: nil,
            audioInstruction: nil,
            audioCompletion: nil,
            itemRule: nil,
            itemEmoji: nil
        )
    }

    private func setupVM(_ lab: Labyrinth? = nil, canvasSize: CGSize = CGSize(width: 300, height: 300)) -> LabyrinthViewModel {
        let vm = LabyrinthViewModel(labyrinth: lab ?? makeSampleLabyrinth())
        vm.canvasSize = canvasSize
        vm.setupValidator(tolerance: 20)
        return vm
    }

    // MARK: - Drawing always works

    func testDrawingAlwaysAppends() {
        let vm = setupVM()

        // Touch anywhere — should start drawing
        vm.handleDragPoint(CGPoint(x: 150, y: 150))
        XCTAssertTrue(vm.hasStartedDrawing)
        XCTAssertEqual(vm.currentStroke.count, 1)

        // More points are drawn
        vm.handleDragPoint(CGPoint(x: 200, y: 200))
        XCTAssertEqual(vm.currentStroke.count, 2)
    }

    // MARK: - Stroke management

    func testHandleDragEndFinalizesStroke() {
        let vm = setupVM()

        vm.handleDragPoint(CGPoint(x: 12, y: 12))
        vm.handleDragPoint(CGPoint(x: 50, y: 12))
        XCTAssertEqual(vm.currentStroke.count, 2)
        XCTAssertTrue(vm.drawingStrokes.isEmpty)

        vm.handleDragEnd()

        XCTAssertTrue(vm.currentStroke.isEmpty, "Current stroke should be cleared after end")
        XCTAssertEqual(vm.drawingStrokes.count, 1, "Should have one finalized stroke")
        XCTAssertEqual(vm.drawingStrokes[0].count, 2)
    }

    func testMultipleStrokesAreIndependent() {
        let vm = setupVM()

        // First stroke
        vm.handleDragPoint(CGPoint(x: 12, y: 12))
        vm.handleDragPoint(CGPoint(x: 50, y: 12))
        vm.handleDragEnd()

        // Second stroke
        vm.handleDragPoint(CGPoint(x: 100, y: 12))
        vm.handleDragPoint(CGPoint(x: 140, y: 12))
        vm.handleDragEnd()

        XCTAssertEqual(vm.drawingStrokes.count, 2)
        XCTAssertEqual(vm.drawingStrokes[0].count, 2)
        XCTAssertEqual(vm.drawingStrokes[1].count, 2)
    }

    // MARK: - Completion (paper-like: just reach the end)

    func testCompletionByReachingEndPoint() {
        let vm = setupVM()

        // Start anywhere and draw to the end
        vm.handleDragPoint(CGPoint(x: 50, y: 50))
        vm.handleDragPoint(CGPoint(x: 288, y: 288))

        XCTAssertTrue(vm.isCompleted, "Should complete when reaching the end point")
        XCTAssertTrue(vm.showSolution, "Should show solution on completion")
    }

    func testCompletionFromStartFollowingPath() {
        let vm = setupVM()

        // Start at start, follow path to end
        vm.handleDragPoint(CGPoint(x: 12, y: 12))
        for x in stride(from: 20.0, through: 150.0, by: 20.0) {
            vm.handleDragPoint(CGPoint(x: x, y: 10))
        }
        for y in stride(from: 20.0, through: 150.0, by: 20.0) {
            vm.handleDragPoint(CGPoint(x: 150, y: y))
        }
        for x in stride(from: 160.0, through: 290.0, by: 20.0) {
            vm.handleDragPoint(CGPoint(x: x, y: 150))
        }
        for y in stride(from: 160.0, through: 290.0, by: 20.0) {
            vm.handleDragPoint(CGPoint(x: 290, y: y))
        }

        XCTAssertTrue(vm.isCompleted, "Should complete after tracing the full path")
    }

    func testNotCompleteWithoutReachingEnd() {
        let vm = setupVM()

        // Draw but don't reach end
        vm.handleDragPoint(CGPoint(x: 12, y: 12))
        vm.handleDragPoint(CGPoint(x: 150, y: 150))

        XCTAssertFalse(vm.isCompleted, "Should not complete without reaching end point")
    }

    func testNoDragAfterCompletion() {
        let vm = setupVM()

        // Complete the maze
        vm.handleDragPoint(CGPoint(x: 288, y: 288))
        XCTAssertTrue(vm.isCompleted)

        let strokeCount = vm.currentStroke.count
        vm.handleDragPoint(CGPoint(x: 100, y: 100))
        XCTAssertEqual(vm.currentStroke.count, strokeCount, "Should not add points after completion")
    }

    // MARK: - Reset

    func testResetClearsAllState() {
        let vm = setupVM()

        vm.handleDragPoint(CGPoint(x: 12, y: 12))
        vm.handleDragPoint(CGPoint(x: 50, y: 12))
        vm.handleDragEnd()

        vm.reset()

        XCTAssertTrue(vm.drawingStrokes.isEmpty)
        XCTAssertTrue(vm.currentStroke.isEmpty)
        XCTAssertFalse(vm.isCompleted)
        XCTAssertFalse(vm.showSolution)
        XCTAssertFalse(vm.hasStartedDrawing)
    }

    // MARK: - Scale and offset

    func testScaleCalculation() {
        let lab = makeSampleLabyrinth()
        let vm = LabyrinthViewModel(labyrinth: lab)
        vm.canvasSize = CGSize(width: 600, height: 600)

        // Canvas is 300x300, view is 600x600 → scale = 2.0
        XCTAssertEqual(vm.scale, 2.0, accuracy: 0.01)
    }

    func testStartAndEndPointsScale() {
        let lab = makeSampleLabyrinth()
        let vm = LabyrinthViewModel(labyrinth: lab)
        vm.canvasSize = CGSize(width: 300, height: 300)

        // Scale 1:1, offset 0 → points match raw data
        XCTAssertEqual(vm.startPoint.x, 10, accuracy: 1)
        XCTAssertEqual(vm.startPoint.y, 10, accuracy: 1)
        XCTAssertEqual(vm.endPoint.x, 290, accuracy: 1)
        XCTAssertEqual(vm.endPoint.y, 290, accuracy: 1)
    }
}

final class ThanksgivingPackTests: IsolatedPreferencesTestCase {
    private let packID = "thanksgiving_adventures"

    func testSevenFixedDifficultyLevelsWithOnlyThreeFree() {
        let expectedStories = Array(67...73)
        for difficulty in [DifficultyLevel.easy, .medium, .hard] {
            let levels = LabyrinthLoader.shared.loadForDifficulty(difficulty, packId: packID)
            XCTAssertEqual(levels.map(\.storyNumber), expectedStories)
            XCTAssertEqual(levels.map(\.difficulty), ["easy", "easy", "medium", "medium", "hard", "hard", "hard"])
        }
        let stories = LabyrinthLoader.shared.loadStories(packId: packID)
        XCTAssertEqual(stories.map(\.isFree), [true, true, true, false, false, false, false])

        let subscription = SubscriptionManager()
        subscription.isPremium = false
        let game = GameViewModel(
            preferences: UserPreferences(defaults: defaults),
            subscriptionManager: subscription,
            progressTracker: ProgressTracker(defaults: defaults)
        )
        game.loadLabyrinths(packId: packID)
        for index in 0..<7 {
            XCTAssertEqual(game.isLabyrinthLocked(at: index), index >= 3)
            XCTAssertEqual(game.isStoryLocked(index + 67), index >= 3)
        }
    }

    func testSeasonalLevelsUseTheExistingDrawingAndCompletionRules() {
        let levels = LabyrinthLoader.shared.loadForDifficulty(.easy, packId: packID)
        XCTAssertEqual(levels.count, 7)
        for level in levels {
            let vm = LabyrinthViewModel(labyrinth: level)
            vm.canvasSize = CGSize(width: level.pathData.canvasWidth, height: level.pathData.canvasHeight)
            vm.setupValidator(tolerance: 20)

            // As in the existing app, drawing can begin anywhere and reaching
            // the goal completes a maze without route or collection gates.
            vm.handleDragPoint(CGPoint(x: 1, y: 1))
            XCTAssertTrue(vm.hasStartedDrawing, level.id)
            XCTAssertEqual(vm.currentStroke.count, 1, level.id)
            vm.handleDragPoint(vm.endPoint)
            XCTAssertTrue(vm.isCompleted, level.id)
            if vm.isCollectType { XCTAssertFalse(vm.allItemsCollected, level.id) }
            XCTAssertFalse(vm.showItemHint, level.id)
        }
    }

    func testSeasonalArtworkAndYoungChildCopy() throws {
        let levels = LabyrinthLoader.shared.loadForDifficulty(.easy, packId: packID)
        XCTAssertEqual(levels.count, 7)
        XCTAssertEqual(levels.map(\.itemRule), ["collect", "collect", "avoid", "collect", "collect", "avoid", "collect"])
        XCTAssertEqual(Set(levels.map { $0.visualTheme.backgroundColor }).count, 7)
        for level in levels {
            XCTAssertNil(level.pathData.backgroundImage, level.id)
            let artwork = try XCTUnwrap(level.pathData.artwork, level.id)
            XCTAssertFalse(artwork.clipPath.isEmpty, level.id)
            XCTAssertFalse(level.pathData.solutionPath.isEmpty, level.id)
            XCTAssertLessThanOrEqual(level.funFact.split(separator: " ").count, 35, level.id)
            if level.itemRule == "avoid" {
                XCTAssertNil(level.pathData.items)
                XCTAssertEqual(level.pathData.avoidItems?.count, 2)
            }
        }
        let turkey = try XCTUnwrap(levels.last)
        let artwork = try XCTUnwrap(turkey.pathData.artwork)
        XCTAssertEqual(turkey.characterEnd.name, "Tilly")
        XCTAssertEqual((turkey.pathData.endPoint.x - artwork.frame.x) / artwork.frame.width * 2000, 1000, accuracy: 5)
        XCTAssertEqual((turkey.pathData.endPoint.y - artwork.frame.y) / artwork.frame.height * 3000, 1996, accuracy: 5)
    }

    func testNextLevelUntilTheFinalSeasonalMaze() {
        let progress = ProgressTracker(defaults: defaults)
        let game = GameViewModel(
            preferences: UserPreferences(defaults: defaults), subscriptionManager: SubscriptionManager(),
            progressTracker: progress
        )
        game.loadLabyrinths(packId: packID)
        for index in 0..<7 {
            game.currentIndex = index
            progress.completedIds.insert(game.currentLabyrinth!.id)
            XCTAssertTrue(game.isStoryComplete)
            XCTAssertEqual(game.shouldReturnToBookshelfAfterCompletion, index == 6)
        }
    }

    func testSeasonalNarrationIsBundledAndDecodable() throws {
        let levels = LabyrinthLoader.shared.loadForDifficulty(.easy, packId: packID)
        XCTAssertEqual(levels.count, 7)
        for level in levels {
            let tracks = [("instruction", level.audioInstruction), ("completion", level.audioCompletion), ("answer", level.audioAnswer)]
            for (track, reference) in tracks {
                let filename = try XCTUnwrap(reference, level.id)
                XCTAssertEqual(filename, String(format: "denny_%03d_%@.mp3", level.storyNumber, track))
                let url = try XCTUnwrap(Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "audio"), filename)
                let player = try AVAudioPlayer(contentsOf: url)
                XCTAssertGreaterThan(player.duration, 1, filename)
            }
        }
    }

    func testThanksgivingCopyIsAvailableInEverySupportedLanguage() {
        let loader = LabyrinthLoader.shared
        loader.setLanguage(.english)
        let english = loader.loadForDifficulty(.easy, packId: packID)
        defer { loader.setLanguage(.english) }
        for language in AppLanguage.allCases where language != .english {
            loader.setLanguage(language)
            let translated = loader.loadForDifficulty(.easy, packId: packID)
            XCTAssertEqual(translated.count, 7, language.rawValue)
            for (original, localized) in zip(english, translated) {
                XCTAssertNotEqual(localized.title, original.title, localized.id)
                XCTAssertNotEqual(localized.instruction, original.instruction, localized.id)
                XCTAssertEqual(localized.storySetup, localized.instruction, localized.id)
                XCTAssertEqual(localized.ttsInstruction, localized.instruction, localized.id)
                XCTAssertNotEqual(localized.educationalQuestion, original.educationalQuestion, localized.id)
                XCTAssertNotEqual(localized.funFact, original.funFact, localized.id)
                XCTAssertNotEqual(localized.completionMessage, original.completionMessage, localized.id)
                XCTAssertNotEqual(localized.location, original.location, localized.id)
                XCTAssertEqual(localized.audioInstruction, original.audioInstruction)
                XCTAssertEqual(localized.audioCompletion, original.audioCompletion)
                XCTAssertEqual(localized.audioAnswer, original.audioAnswer)
            }
        }
    }

    func testArchivedFallContentIsExcludedFromTheApp() throws {
        let manifest = try XCTUnwrap(LabyrinthLoader.shared.loadManifest())
        XCTAssertNil(LabyrinthLoader.shared.packInfo(packId: "fall_adventures"))
        XCTAssertFalse(manifest.labyrinths.contains { (61...66).contains($0.story ?? 0) })
        for story in 61...66 {
            for difficulty in ["easy", "medium", "hard"] {
                XCTAssertNil(Bundle.main.url(forResource: String(format: "denny_%03d_%@", story, difficulty), withExtension: "json"))
            }
            for track in ["instruction", "completion", "answer"] {
                XCTAssertNil(Bundle.main.url(forResource: String(format: "denny_%03d_%@", story, track), withExtension: "mp3", subdirectory: "audio"))
            }
        }
    }
}
