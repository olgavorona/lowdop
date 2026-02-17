import XCTest
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
                controlPoints: nil
            ),
            visualTheme: VisualTheme(backgroundColor: "#4A90E2", decorativeElements: []),
            location: nil,
            audioInstruction: nil,
            audioCompletion: nil
        )
    }

    private func setupVM(_ lab: Labyrinth? = nil, canvasSize: CGSize = CGSize(width: 300, height: 300)) -> LabyrinthViewModel {
        let vm = LabyrinthViewModel(labyrinth: lab ?? makeSampleLabyrinth())
        vm.canvasSize = canvasSize
        vm.setupValidator(tolerance: 20)
        return vm
    }

    // MARK: - Drawing always works (no blocked strokes)

    func testDrawingAlwaysAppends() {
        let vm = setupVM()

        // Touch anywhere — should start drawing
        vm.handleDragPoint(CGPoint(x: 150, y: 150))
        XCTAssertTrue(vm.hasStartedDrawing)
        XCTAssertEqual(vm.currentStroke.count, 1)

        // Even off-path points are drawn
        vm.handleDragPoint(CGPoint(x: 200, y: 200))
        XCTAssertEqual(vm.currentStroke.count, 2)
    }

    func testOffPathPointsChangeColor() {
        let vm = setupVM()

        // Start on path
        vm.handleDragPoint(CGPoint(x: 12, y: 12))
        XCTAssertTrue(vm.isOnPath)

        // Move off path — isOnPath should turn false
        vm.handleDragPoint(CGPoint(x: 50, y: 200))
        XCTAssertFalse(vm.isOnPath)
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

    // MARK: - Completion validation

    func testCompletionRequiresStartNearStartPoint() {
        let vm = setupVM()

        // Start far from start point (150,150 instead of 10,10)
        vm.handleDragPoint(CGPoint(x: 150, y: 150))

        // Walk through remaining segments
        for x in stride(from: 160.0, through: 290.0, by: 20.0) {
            vm.handleDragPoint(CGPoint(x: x, y: 150))
        }
        for y in stride(from: 160.0, through: 290.0, by: 20.0) {
            vm.handleDragPoint(CGPoint(x: 290, y: y))
        }

        XCTAssertFalse(vm.isCompleted, "Should not complete when drawing didn't start near start")
    }

    func testCompletionRequiresEnoughSegmentsVisited() {
        let vm = setupVM()

        // Start near start
        vm.handleDragPoint(CGPoint(x: 12, y: 12))

        // Only walk segment 0 (1 out of 4 = 25%, need 50%)
        for x in stride(from: 20.0, through: 140.0, by: 10.0) {
            vm.handleDragPoint(CGPoint(x: x, y: 10))
        }

        XCTAssertFalse(vm.isCompleted, "Should not complete with only 1 of 4 segments visited")
    }

    func testCompletionByFollowingFullPath() {
        let vm = setupVM()

        // Start at start
        vm.handleDragPoint(CGPoint(x: 12, y: 12))

        // Walk along segment 0 (horizontal at y=10)
        for x in stride(from: 20.0, through: 150.0, by: 20.0) {
            vm.handleDragPoint(CGPoint(x: x, y: 10))
        }

        // Walk along segment 1 (vertical at x=150)
        for y in stride(from: 20.0, through: 150.0, by: 20.0) {
            vm.handleDragPoint(CGPoint(x: 150, y: y))
        }

        // Walk along segment 2 (horizontal at y=150)
        for x in stride(from: 160.0, through: 290.0, by: 20.0) {
            vm.handleDragPoint(CGPoint(x: x, y: 150))
        }

        // Walk along segment 3 (vertical at x=290)
        for y in stride(from: 160.0, through: 290.0, by: 20.0) {
            vm.handleDragPoint(CGPoint(x: 290, y: y))
        }

        XCTAssertTrue(vm.isCompleted, "Should complete after tracing the full path from start to end")
    }

    func testCannotCompleteByTouchingEndOnly() {
        let vm = setupVM()

        // Just touch the end point directly — has no startedNearStart
        vm.handleDragPoint(CGPoint(x: 288, y: 288))

        XCTAssertFalse(vm.isCompleted, "Should not complete by just touching end point")
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
        XCTAssertTrue(vm.isOnPath)
        XCTAssertFalse(vm.isCompleted)
        XCTAssertFalse(vm.showSolution)
        XCTAssertFalse(vm.hasStartedDrawing)
    }
}
