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
                controlPoints: nil,
                items: nil
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
