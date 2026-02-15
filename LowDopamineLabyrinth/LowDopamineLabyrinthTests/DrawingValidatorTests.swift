import XCTest
@testable import LowDopamineLabyrinth

final class DrawingValidatorTests: XCTestCase {

    // Simple horizontal segment from (0,0) to (100,0), no scaling
    private func makeValidator(segments: [SegmentData], tolerance: CGFloat = 15) -> DrawingValidator {
        DrawingValidator(segments: segments, tolerance: tolerance, scale: 1.0, offset: .zero)
    }

    private func segment(from: (Double, Double), to: (Double, Double)) -> SegmentData {
        SegmentData(
            start: PointData(x: from.0, y: from.1),
            end: PointData(x: to.0, y: to.1)
        )
    }

    // MARK: - isPointOnPath

    func testPointOnSegmentIsOnPath() {
        let v = makeValidator(segments: [segment(from: (0, 0), to: (100, 0))])
        XCTAssertTrue(v.isPointOnPath(CGPoint(x: 50, y: 0)))
    }

    func testPointNearSegmentIsOnPath() {
        let v = makeValidator(segments: [segment(from: (0, 0), to: (100, 0))], tolerance: 15)
        XCTAssertTrue(v.isPointOnPath(CGPoint(x: 50, y: 10)))
    }

    func testPointFarFromSegmentIsNotOnPath() {
        let v = makeValidator(segments: [segment(from: (0, 0), to: (100, 0))], tolerance: 15)
        XCTAssertFalse(v.isPointOnPath(CGPoint(x: 50, y: 50)))
    }

    func testPointNearStartOfSegment() {
        let v = makeValidator(segments: [segment(from: (0, 0), to: (100, 0))], tolerance: 10)
        XCTAssertTrue(v.isPointOnPath(CGPoint(x: 2, y: 5)))
    }

    func testPointNearEndOfSegment() {
        let v = makeValidator(segments: [segment(from: (0, 0), to: (100, 0))], tolerance: 10)
        XCTAssertTrue(v.isPointOnPath(CGPoint(x: 98, y: 5)))
    }

    // MARK: - nearestSegmentIndex

    func testNearestSegmentIndex() {
        let segments = [
            segment(from: (0, 0), to: (100, 0)),     // index 0: horizontal at y=0
            segment(from: (100, 0), to: (100, 100)),  // index 1: vertical at x=100
            segment(from: (100, 100), to: (200, 100)), // index 2: horizontal at y=100
        ]
        let v = makeValidator(segments: segments)

        // Point near segment 0
        XCTAssertEqual(v.nearestSegmentIndex(to: CGPoint(x: 50, y: 5)), 0)

        // Point near segment 1
        XCTAssertEqual(v.nearestSegmentIndex(to: CGPoint(x: 105, y: 50)), 1)

        // Point near segment 2
        XCTAssertEqual(v.nearestSegmentIndex(to: CGPoint(x: 150, y: 95)), 2)
    }

    // MARK: - isNearStart / isNearEnd

    func testIsNearStart() {
        let v = makeValidator(segments: [segment(from: (10, 10), to: (100, 100))])
        let startPoint = PointData(x: 10, y: 10)

        XCTAssertTrue(v.isNearStart(CGPoint(x: 12, y: 12), startPoint: startPoint, radius: 10))
        XCTAssertFalse(v.isNearStart(CGPoint(x: 50, y: 50), startPoint: startPoint, radius: 10))
    }

    func testIsNearEnd() {
        let v = makeValidator(segments: [segment(from: (0, 0), to: (100, 100))])
        let endPoint = PointData(x: 100, y: 100)

        XCTAssertTrue(v.isNearEnd(CGPoint(x: 98, y: 98), endPoint: endPoint, radius: 10))
        XCTAssertFalse(v.isNearEnd(CGPoint(x: 50, y: 50), endPoint: endPoint, radius: 10))
    }

    // MARK: - Scaling

    func testScaledValidation() {
        // Segment from (0,0) to (100,0) at scale 2.0 → effective (0,0) to (200,0)
        let v = DrawingValidator(
            segments: [segment(from: (0, 0), to: (100, 0))],
            tolerance: 10,
            scale: 2.0,
            offset: .zero
        )

        // Point at (100, 5) — midpoint of scaled segment, within tolerance
        XCTAssertTrue(v.isPointOnPath(CGPoint(x: 100, y: 5)))

        // Point at (250, 5) — past end of scaled segment
        XCTAssertFalse(v.isPointOnPath(CGPoint(x: 250, y: 5)))
    }

    func testOffsetValidation() {
        // Segment from (0,0) to (100,0) with offset (50, 50)
        let v = DrawingValidator(
            segments: [segment(from: (0, 0), to: (100, 0))],
            tolerance: 10,
            scale: 1.0,
            offset: CGPoint(x: 50, y: 50)
        )

        // Point at (100, 55) — on the offset segment, within tolerance
        XCTAssertTrue(v.isPointOnPath(CGPoint(x: 100, y: 55)))

        // Point at (0, 0) — far from offset segment
        XCTAssertFalse(v.isPointOnPath(CGPoint(x: 0, y: 0)))
    }
}
