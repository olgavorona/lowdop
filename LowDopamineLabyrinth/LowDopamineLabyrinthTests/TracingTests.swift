import XCTest
import SwiftUI
@testable import LowDopamineLabyrinth

final class TracingTests: XCTestCase {
    func testABCIsDefaultAndOriginalAndHiraganaIconsAreBundled() throws {
        let icons = try XCTUnwrap(Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])
        let primary = try XCTUnwrap(icons["CFBundlePrimaryIcon"] as? [String: Any])
        XCTAssertEqual(primary["CFBundleIconName"] as? String, "AppIconABC")
        let alternatives = try XCTUnwrap(icons["CFBundleAlternateIcons"] as? [String: Any])
        XCTAssertEqual(Set(alternatives.keys), Set(["AppIcon", "AppIconHiragana"]))
        XCTAssertNil(alternatives["AppIconD"])
    }

    func testCollectionAvailabilityInEveryLanguage() {
        for language in AppLanguage.allCases {
            XCTAssertTrue(TracingCollection.letters.isAvailable(in: language))
            XCTAssertTrue(TracingCollection.numbers.isAvailable(in: language))
            XCTAssertEqual(TracingCollection.hiragana.isAvailable(in: language), language == .japanese)
        }
    }

    func testEveryDigitHasACompleteVisiblePathAndDirection() {
        XCTAssertEqual(String(TracingCollection.numbers.characters), "0123456789")
        for character in TracingCollection.numbers.characters {
            verifyPaths(TracingCollection.numbers.strokes(for: String(character)))
        }
    }

    func testOneHasSeparateRisingAndDownwardStrokes() throws {
        let strokes = TracingCollection.numbers.strokes(for: "1")
        XCTAssertEqual(strokes.count, 2)
        guard strokes.count == 2 else { return }
        let firstEnd = try XCTUnwrap(strokes[0].curves.last).end
        XCTAssertGreaterThan(firstEnd.x, strokes[0].start.x)
        XCTAssertLessThan(firstEnd.y, strokes[0].start.y)
        XCTAssertEqual(strokes[1].start, firstEnd)
        XCTAssertEqual(try XCTUnwrap(strokes[1].curves.last).end, TracingPoint(61, 87))
    }

    func testGeneratedAlphabetCoversBothCasesIncludingDotsAndDescenders() throws {
        for character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" {
            verifyPaths(TracingCollection.letters.strokes(for: String(character)))
        }
        for character in ["i", "j"] {
            let strokes = TracingCollection.letters.strokes(for: character)
            XCTAssertEqual(strokes.count, 2)
            XCTAssertTrue(try XCTUnwrap(strokes.last).isDot)
        }
        for character in ["g", "j", "p", "q", "y"] {
            let dots = TracingCollection.letters.strokes(for: character).flatMap {
                $0.spacedPoints(in: CGSize(width: 109, height: 109), spacing: 1)
            }
            XCTAssertGreaterThan(try XCTUnwrap(dots.map(\.y).max()), 98, character)
        }
        for character in ["O", "S", "U", "o", "s"] {
            XCTAssertEqual(TracingCollection.letters.strokes(for: character).count, 1, character)
        }
    }

    func testNumberRowsFitMoreThanTwoReadableCopiesOnTablets() {
        for character in TracingCollection.numbers.characters {
            let glyph = TracingCollection.numbers.strokes(for: String(character))
            for size in [CGSize(width: 600, height: 500), CGSize(width: 1000, height: 330)] {
                let layout = TracingRowLayout(size: size, collection: .numbers, glyphs: [glyph])
                XCTAssertGreaterThan(layout.copies, 2, String(character))
                XCTAssertGreaterThanOrEqual(layout.glyphHeight, 240)
                verifyLayout(layout, size: size)
            }
        }
    }

    func testRowsFitBothLetterCasesAndSmallPhoneScreensWithoutDistortingGlyphs() {
        for collection in TracingCollection.allCases {
            for character in collection.characters {
                let symbols = collection == .letters ? [String(character), String(character).lowercased()] : [String(character)]
                let glyphs = symbols.map { collection.strokes(for: $0) }
                for size in [CGSize(width: 220, height: 260), CGSize(width: 650, height: 140)] {
                    let layout = TracingRowLayout(size: size, collection: collection, glyphs: glyphs)
                    verifyLayout(layout, size: size)
                    for (index, glyph) in glyphs.enumerated() {
                        let aspect = TracingStroke.contentBounds(for: glyph).width / 109
                        XCTAssertEqual(layout.glyphWidths[index] / layout.glyphHeight, aspect, accuracy: 0.001)
                    }
                }
            }
        }
    }

    func testBundledHiraganaIncludesAll46BasicKanaWithOrderedStrokes() {
        let collection = TracingCollection.hiragana
        XCTAssertEqual(collection.characters.count, 46)
        XCTAssertEqual(Set(collection.characters).count, 46)
        XCTAssertEqual(String(collection.characters.prefix(5)), "あいうえお")
        XCTAssertEqual(String(collection.characters.suffix(3)), "わをん")
        for character in collection.characters {
            verifyPaths(collection.strokes(for: String(character)))
        }
        // Handwritten forms must retain pen lifts that printed fonts often join.
        XCTAssertEqual(collection.strokes(for: "き").count, 4)
        XCTAssertEqual(collection.strokes(for: "さ").count, 3)
        XCTAssertEqual(collection.strokes(for: "ふ").count, 4)
        XCTAssertEqual(collection.strokes(for: "り").count, 2)
    }

    func testComplexKanaPreservesSourceStrokeOrderAndFullLoops() throws {
        let strokes = TracingCollection.hiragana.strokes(for: "あ")
        XCTAssertEqual(strokes.count, 3)
        guard strokes.count == 3 else { return }
        XCTAssertEqual(strokes[0].start, TracingPoint(31.01, 33))
        XCTAssertEqual(strokes[1].start, TracingPoint(49.76, 17.62))
        XCTAssertEqual(strokes[2].start, TracingPoint(65.63, 44.12))
        XCTAssertEqual(strokes[2].curves.count, 6, "The loop must keep all six source curves")
        XCTAssertEqual(try XCTUnwrap(strokes[2].curves.last).end, TracingPoint(66.51, 94.12))
    }

    func testDotsUseDistanceRatherThanCurveParameter() throws {
        let stroke = TracingStroke(
            start: TracingPoint(0, 0), curves: [TracingCurve(0, 0, 0, 0, 109, 0)],
            numberPosition: TracingPoint(0, 0)
        )
        let points = stroke.spacedPoints(in: CGSize(width: 109, height: 109), spacing: 10)
        XCTAssertEqual(points.count, 11)
        for (index, point) in points.enumerated() {
            XCTAssertEqual(point.x, CGFloat(index * 10), accuracy: 0.01)
            XCTAssertEqual(point.y, 0)
        }
    }

    func testClosedLoopsHaveCorrectLocalDirection() throws {
        let stroke = try XCTUnwrap(TracingCollection.numbers.strokes(for: "0").first)
        let cue = try XCTUnwrap(stroke.directionCue(in: CGSize(width: 109, height: 109)))
        XCTAssertTrue(cue.angle.isFinite)
        XCTAssertGreaterThan(sin(cue.angle), 0, "The left side of zero must go down, counterclockwise from the top")
    }

    func testNavigationClearsDrawingAndStopsAtCollectionBoundaries() {
        for collection in TracingCollection.allCases {
            let viewModel = LetterTracingViewModel(collection: collection, initialIndex: -1)
            XCTAssertEqual(viewModel.currentLetter, String(collection.characters[0]))
            XCTAssertFalse(viewModel.canGoPrevious)
            viewModel.previous()
            XCTAssertEqual(viewModel.currentIndex, 0)

            viewModel.handleDragPoint(CGPoint(x: 10, y: 20))
            viewModel.handleDragPoint(CGPoint(x: 30, y: 40))
            viewModel.handleDragEnd()
            XCTAssertEqual(viewModel.drawingStrokes.count, 1)
            viewModel.next()
            XCTAssertEqual(viewModel.currentIndex, 1)
            XCTAssertTrue(viewModel.drawingStrokes.isEmpty)
            XCTAssertTrue(viewModel.currentStroke.isEmpty)

            let last = LetterTracingViewModel(collection: collection, initialIndex: .max)
            XCTAssertEqual(last.currentLetter, String(collection.characters.last!))
            XCTAssertFalse(last.canGoNext)
            last.next()
            XCTAssertEqual(last.currentIndex, collection.characters.count - 1)
            last.handleDragPoint(CGPoint(x: 1, y: 1))
            last.restart()
            XCTAssertTrue(last.currentStroke.isEmpty)
            XCTAssertEqual(last.currentIndex, collection.characters.count - 1)
        }
    }

    private func verifyPaths(_ strokes: [TracingStroke], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(strokes.isEmpty, file: file, line: line)
        for stroke in strokes {
            XCTAssertFalse(stroke.curves.isEmpty, file: file, line: line)
            let size = CGSize(width: 420, height: 420)
            XCTAssertFalse(stroke.path(in: size).isEmpty, file: file, line: line)
            let dots = stroke.spacedPoints(in: size, spacing: 22)
            XCTAssertFalse(dots.isEmpty, file: file, line: line)
            for point in dots {
                XCTAssertTrue(point.x.isFinite && point.y.isFinite, file: file, line: line)
                XCTAssertTrue(CGRect(origin: .zero, size: size).insetBy(dx: -1, dy: -1).contains(point), file: file, line: line)
            }
            if !stroke.isDot {
                XCTAssertNotNil(stroke.directionCue(in: size), file: file, line: line)
            }
        }
    }

    private func verifyLayout(_ layout: TracingRowLayout, size: CGSize, file: StaticString = #filePath, line: UInt = #line) {
        let groupWidth = layout.glyphWidths.reduce(0, +) + CGFloat(layout.glyphWidths.count - 1) * layout.glyphSpacing
        let occupied = CGFloat(layout.copies) * groupWidth + CGFloat(layout.copies - 1) * layout.copySpacing
        XCTAssertLessThanOrEqual(occupied, size.width - 32 + 0.01, file: file, line: line)
        XCTAssertLessThanOrEqual(layout.glyphHeight, size.height - 24 + 0.01, file: file, line: line)
    }
}
