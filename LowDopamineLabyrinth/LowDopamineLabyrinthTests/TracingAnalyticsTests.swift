import XCTest
@testable import LowDopamineLabyrinth

final class TracingAnalyticsTests: XCTestCase {
    private final class Recorder {
        var time: TimeInterval = 0
        var events: [(name: String, properties: [String: String], value: Double?)] = []

        func model(_ collection: TracingCollection = .letters, index: Int = 0, locale: String = "en") -> LetterTracingViewModel {
            LetterTracingViewModel(
                collection: collection, initialIndex: index, appLocale: locale,
                eventSender: { self.events.append(($0, $1, $2)) }, analyticsClock: { self.time }
            )
        }

        func properties(for event: String) -> [[String: String]] {
            events.filter { $0.name == event }.map(\.properties)
        }
    }

    func testCollectionOpensUseTheSameSchemaForAllThreeCollections() {
        for collection in TracingCollection.allCases {
            let recorder = Recorder()
            TracingAnalytics.collectionOpened(collection, appLocale: "ja") {
                recorder.events.append(($0, $1, $2))
            }
            XCTAssertEqual(recorder.events.count, 1)
            XCTAssertEqual(recorder.events.first?.name, "Tracing.collectionOpened")
            XCTAssertEqual(recorder.events.first?.properties, [
                "collection": collection.rawValue, "app_locale": "ja",
                "character_count": String(collection.characters.count)
            ])
        }
    }

    func testSessionStartCloseAndNavigationDoNotDuplicateEventsOrCountAsResets() throws {
        let recorder = Recorder()
        let model = recorder.model()
        model.startSession()
        model.startSession()
        XCTAssertEqual(recorder.events.map(\.name), ["Tracing.sessionStarted", "Tracing.characterViewed"])
        XCTAssertEqual(recorder.events[0].properties["character"], "A")
        XCTAssertEqual(recorder.events[0].properties["lowercase_character"], "a")

        recorder.time = 4
        model.next()
        recorder.time = 6
        model.previous()
        let count = recorder.events.count
        model.previous()
        XCTAssertEqual(recorder.events.count, count, "Disabled navigation must not emit events")
        recorder.time = 10
        model.endSession(reason: "close")
        model.endSession(reason: "dismissed")

        let views = recorder.properties(for: "Tracing.characterViewed")
        XCTAssertEqual(views.compactMap { $0["character"] }, ["A", "B", "A"])
        XCTAssertEqual(views.compactMap { $0["entry"] }, ["grid", "next", "previous"])
        let segments = recorder.properties(for: "Tracing.engagement")
        XCTAssertEqual(segments.compactMap { $0["active_seconds"] }, ["4.00", "2.00", "4.00"])
        XCTAssertEqual(segments.compactMap { $0["reason"] }, ["next", "previous", "close"])
        XCTAssertEqual(segments.first?["next_character"], "B")
        XCTAssertTrue(recorder.properties(for: "Tracing.reset").isEmpty)
        let summaries = recorder.properties(for: "Tracing.sessionEnded")
        XCTAssertEqual(summaries.count, 1)
        let summary = try XCTUnwrap(summaries.first)
        XCTAssertEqual(summary["active_seconds"], "10.00")
        XCTAssertEqual(recorder.events.first { $0.name == "Tracing.sessionEnded" }?.value, 10)
        XCTAssertEqual(summary["characters_viewed"], "3")
        XCTAssertEqual(summary["unique_characters_viewed"], "2")
        XCTAssertEqual(summary["characters_practiced"], "0")
        XCTAssertEqual(summary["reset_count"], "0")
        XCTAssertNil(summary["character"], "Session totals must not be attributed to the final character")
    }

    func testDrawingIsRecordedOncePerVisitAndAllAttemptsSurviveReset() throws {
        let recorder = Recorder()
        let model = recorder.model(.numbers, index: 1)
        model.startSession()
        recorder.time = 1
        model.handleDragPoint(CGPoint(x: 10, y: 20))
        model.handleDragPoint(CGPoint(x: 20, y: 30))
        recorder.time = 2
        model.handleDragEnd()
        recorder.time = 3
        model.handleDragPoint(CGPoint(x: 30, y: 40))
        model.handleDragPoint(CGPoint(x: 40, y: 50))
        recorder.time = 4
        model.handleDragEnd()
        recorder.time = 5
        model.restart()
        XCTAssertTrue(model.drawingStrokes.isEmpty)
        XCTAssertEqual(recorder.properties(for: "Tracing.reset").first?["cleared_stroke_count"], "2")
        recorder.time = 6
        model.handleDragPoint(CGPoint(x: 10, y: 20))
        recorder.time = 7
        model.handleDragEnd()
        recorder.time = 10
        model.endSession(reason: "close")

        XCTAssertEqual(recorder.properties(for: "Tracing.drawingStarted").count, 1)
        let summary = try XCTUnwrap(recorder.properties(for: "Tracing.sessionEnded").first)
        XCTAssertEqual(summary["collection"], "number_tracing")
        XCTAssertEqual(summary["stroke_count"], "3")
        XCTAssertEqual(summary["reset_count"], "1")
        XCTAssertEqual(summary["characters_practiced"], "1")
        XCTAssertEqual(summary["drawing_seconds"], "3.00")
        XCTAssertEqual(summary["active_seconds"], "10.00")
        XCTAssertEqual(recorder.events.first { $0.name == "Tracing.drawingDuration" }?.value, 3)
        XCTAssertFalse(recorder.events.contains { $0.properties["points"] != nil || $0.properties["x"] != nil || $0.properties["y"] != nil })
    }

    func testBackgroundCheckpointsExcludeBackgroundTimeAndDoNotDoubleCount() throws {
        let recorder = Recorder()
        let model = recorder.model(.hiragana, locale: "ja")
        model.startSession()
        recorder.time = 1
        model.handleDragPoint(CGPoint(x: 10, y: 20))
        recorder.time = 3
        model.pauseAnalytics(isBackground: false)
        recorder.time = 5
        model.pauseAnalytics(isBackground: true)
        recorder.time = 50
        model.pauseAnalytics(isBackground: true)
        XCTAssertEqual(recorder.properties(for: "Tracing.engagement").count, 1)
        recorder.time = 103
        model.resumeAnalytics()
        recorder.time = 104
        model.handleDragPoint(CGPoint(x: 20, y: 30))
        recorder.time = 106
        model.handleDragEnd()
        recorder.time = 108
        model.endSession(reason: "close")

        let segments = recorder.properties(for: "Tracing.engagement")
        XCTAssertEqual(segments.compactMap { $0["active_seconds"] }, ["3.00", "5.00"])
        XCTAssertEqual(segments.compactMap { $0["drawing_seconds"] }, ["2.00", "2.00"])
        XCTAssertEqual(segments.compactMap { $0["stroke_count"] }, ["1", "1"])
        XCTAssertEqual(segments.compactMap { $0["reason"] }, ["background", "close"])
        XCTAssertEqual(segments.first?["character"], "あ")
        XCTAssertEqual(segments.first?["app_locale"], "ja")
        XCTAssertEqual(recorder.properties(for: "Tracing.drawingStarted").count, 1)
        let summary = try XCTUnwrap(recorder.properties(for: "Tracing.sessionEnded").first)
        XCTAssertEqual(summary["active_seconds"], "8.00")
        XCTAssertEqual(summary["drawing_seconds"], "4.00")
        XCTAssertEqual(summary["stroke_count"], "2")
        XCTAssertEqual(recorder.events.filter { $0.name == "Tracing.engagement" }.compactMap(\.value), [3, 5])
        XCTAssertEqual(recorder.events.filter { $0.name == "Tracing.drawingDuration" }.compactMap(\.value), [2, 2])
    }

    func testRevisitingKanaRecordsInterestAgainButCountsUniquePracticeOnce() throws {
        let recorder = Recorder()
        let model = recorder.model(.hiragana, index: 45, locale: "ja")
        model.startSession()
        let count = recorder.events.count
        model.next()
        XCTAssertEqual(recorder.events.count, count)
        for (index, start) in [1.0, 4.0, 7.0].enumerated() {
            recorder.time = start
            model.handleDragPoint(CGPoint(x: 10, y: 20))
            recorder.time = start + 1
            model.handleDragEnd()
            recorder.time = start + 2
            if index == 0 { model.previous() }
            if index == 1 { model.next() }
        }
        model.endSession(reason: "close")
        XCTAssertEqual(recorder.properties(for: "Tracing.drawingStarted").compactMap { $0["character"] }, ["ん", "を", "ん"])
        let summary = try XCTUnwrap(recorder.properties(for: "Tracing.sessionEnded").first)
        XCTAssertEqual(summary["characters_viewed"], "3")
        XCTAssertEqual(summary["unique_characters_viewed"], "2")
        XCTAssertEqual(summary["characters_practiced"], "2")
        XCTAssertEqual(summary["stroke_count"], "3")
    }

    func testResetDuringAStrokeStopsDrawingTimerAndCountsOnlyTheExplicitReset() throws {
        let recorder = Recorder()
        let model = recorder.model(.numbers)
        model.startSession()
        recorder.time = 1
        model.handleDragPoint(CGPoint(x: 10, y: 20))
        recorder.time = 3
        model.restart()
        XCTAssertTrue(model.currentStroke.isEmpty)
        XCTAssertEqual(recorder.properties(for: "Tracing.reset").first?["cleared_stroke_count"], "1")
        recorder.time = 10
        model.endSession(reason: "close")
        let summary = try XCTUnwrap(recorder.properties(for: "Tracing.sessionEnded").first)
        XCTAssertEqual(summary["active_seconds"], "10.00")
        XCTAssertEqual(summary["drawing_seconds"], "2.00")
        XCTAssertEqual(summary["reset_count"], "1")
    }

    func testInactiveStartEmptyDismissalAndFurtherCallbacksAreHandledOnce() throws {
        let recorder = Recorder()
        let model = recorder.model()
        model.endSession(reason: "dismissed")
        XCTAssertTrue(recorder.events.isEmpty)
        model.startSession(isActive: false)
        recorder.time = 100
        model.resumeAnalytics()
        recorder.time = 103
        model.endSession(reason: "dismissed")
        let count = recorder.events.count
        model.endSession(reason: "close")
        model.resumeAnalytics()
        model.pauseAnalytics(isBackground: true)
        model.restart()
        model.next()
        model.handleDragPoint(.zero)
        model.handleDragEnd()
        XCTAssertEqual(recorder.events.count, count)
        let summary = try XCTUnwrap(recorder.properties(for: "Tracing.sessionEnded").first)
        XCTAssertEqual(summary["active_seconds"], "3.00")
        XCTAssertEqual(summary["stroke_count"], "0")
        XCTAssertEqual(summary["characters_practiced"], "0")
        XCTAssertEqual(summary["reason"], "dismissed")
    }

    func testDurationFormattingDoesNotFollowTheSelectedLanguage() throws {
        let recorder = Recorder()
        let model = recorder.model(locale: "de")
        model.startSession()
        recorder.time = 1.25
        model.endSession(reason: "close")
        let summary = try XCTUnwrap(recorder.properties(for: "Tracing.sessionEnded").first)
        XCTAssertEqual(summary["app_locale"], "de")
        XCTAssertEqual(summary["active_seconds"], "1.25")
    }
}
