import XCTest

final class LowDopamineLabyrinthUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLastLevelCompletionReturnsToBookshelf() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestDisableAnalytics",
            "-uiTestSelectedPack", "ocean_adventures",
            "-uiTestShowCompletionForLastLevel"
        ]

        app.launch()

        let completionButton = app.buttons["completion.primaryButton"]
        XCTAssertTrue(completionButton.waitForExistence(timeout: 10))
        XCTAssertEqual(completionButton.label, "Back to Bookshelf")

        completionButton.tap()

        let bookshelfTitle = app.staticTexts["bookshelf.title"]
        XCTAssertTrue(bookshelfTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(bookshelfTitle.label, "Your Adventures")
        XCTAssertFalse(app.staticTexts["grid.title"].exists)
    }
}

/// Run on a dedicated simulator: launch arguments override preferences only in that app.
final class TracingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testBookshelfAvailabilityForEveryLanguage() {
        for language in ["en", "de", "es", "ja", "zh-Hans"] {
            let app = launch(language: language)
            XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
            // Allow for tracing cards being below the visible area on short screens.
            if !app.buttons["bookshelf.pack.number_tracing"].exists {
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(app.buttons["bookshelf.pack.number_tracing"].exists, language)
            XCTAssertEqual(app.buttons["bookshelf.pack.hiragana_tracing"].exists, language == "ja", language)
            if language == "ja" {
                XCTAssertTrue(app.buttons["bookshelf.pack.hiragana_tracing"].label.contains("あ"))
            }
            if language == "en" || language == "ja" {
                attachScreenshot(app, name: "Bookshelf rows \(language) portrait")
            }
            if language == "ja" {
                XCUIDevice.shared.orientation = .landscapeLeft
                app.scrollViews.firstMatch.swipeUp()
                attachScreenshot(app, name: "Bookshelf rows Japanese landscape")
                XCUIDevice.shared.orientation = .portrait
            }
            app.terminate()
        }
    }

    func testNumbersDrawRestartNavigateAndClose() {
        let app = launch(language: "en", pack: "number_tracing")
        let zero = app.buttons["tracing.glyph.0"]
        XCTAssertTrue(zero.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tracing.glyph.9"].exists)
        zero.tap()
        let example = element("tracing.example", in: app)
        XCTAssertTrue(example.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(example.label, "0")
        XCTAssertFalse(app.buttons["tracing.previous"].isEnabled)

        let practice = element("tracing.practice", in: app)
        practice.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: practice.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.7)))
        app.buttons["tracing.restart"].tap()
        app.buttons["tracing.next"].tap()
        XCTAssertEqual(example.label, "1")
        attachScreenshot(app, name: "Number 1 ordered and dotted examples above gray guides")
        app.buttons["tracing.previous"].tap()
        XCTAssertEqual(example.label, "0")
        attachScreenshot(app, name: "Number tracing")
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["tracing.restart"].tap()
        attachScreenshot(app, name: "More number copies in landscape")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["tracing.restart"].tap()
        app.buttons["tracing.close"].tap()
        XCTAssertTrue(zero.waitForExistence(timeout: 5))
    }

    func testHiraganaPathsAndLastCharacterAreReachable() {
        let app = launch(language: "ja", pack: "hiragana_tracing")
        let first = app.buttons["tracing.glyph.あ"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        let example = element("tracing.example", in: app)
        XCTAssertTrue(example.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(example.label, "あ")
        attachScreenshot(app, name: "Hiragana あ stroke order")
        for _ in 0..<6 { app.buttons["tracing.next"].tap() }
        XCTAssertEqual(example.label, "き")
        attachScreenshot(app, name: "Hiragana き four separate strokes")
        XCUIDevice.shared.orientation = .landscapeLeft
        // Tapping waits for rotation to settle before taking the landscape capture.
        app.buttons["tracing.restart"].tap()
        XCTAssertTrue(app.buttons["tracing.close"].isHittable)
        attachScreenshot(app, name: "Hiragana landscape")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["tracing.restart"].tap()
        app.buttons["tracing.close"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let last = app.buttons["tracing.glyph.ん"]
        for _ in 0..<8 {
            if last.exists && last.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(last.isHittable, app.debugDescription)
        last.tap()
        XCTAssertTrue(example.waitForExistence(timeout: 5))
        XCTAssertEqual(example.label, "ん")
        XCTAssertFalse(app.buttons["tracing.next"].isEnabled)
    }

    func testHiraganaRouteIsUnavailableOutsideJapanese() {
        let app = launch(language: "en", pack: "hiragana_tracing")
        XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["tracing.glyph.あ"].exists)
    }

    func testAlphabetStillUsesExistingLetterGridAndControls() {
        let app = launch(language: "en", pack: "letter_tracing")
        let a = app.buttons["tracing.glyph.A"]
        XCTAssertTrue(a.waitForExistence(timeout: 10))
        a.tap()
        XCTAssertTrue(app.buttons["tracing.close"].waitForExistence(timeout: 10), app.debugDescription)
        let example = element("tracing.example", in: app)
        XCTAssertEqual(example.label, "A a")
        XCTAssertEqual(element("tracing.practice", in: app).label, "A a")
        attachScreenshot(app, name: "Generated uppercase and lowercase A a")
        XCTAssertFalse(app.buttons["tracing.previous"].isEnabled)
        app.buttons["tracing.next"].tap()
        XCTAssertEqual(example.label, "B b")
        XCTAssertTrue(app.buttons["tracing.previous"].isEnabled)
        app.buttons["tracing.close"].tap()
        XCTAssertTrue(a.waitForExistence(timeout: 5))
    }

    func testGeneratedLowercaseLoopsDotsAndDescenders() {
        let app = launch(language: "en", pack: "letter_tracing")
        let g = app.buttons["tracing.glyph.G"]
        XCTAssertTrue(g.waitForExistence(timeout: 10))
        g.tap()
        let example = element("tracing.example", in: app)
        XCTAssertTrue(example.waitForExistence(timeout: 10))
        XCTAssertEqual(example.label, "G g")
        attachScreenshot(app, name: "Generated G g and lowercase descender")
        app.buttons["tracing.next"].tap()
        app.buttons["tracing.next"].tap()
        XCTAssertEqual(example.label, "I i")
        attachScreenshot(app, name: "Generated I i with separate dot")
        app.buttons["tracing.next"].tap()
        XCTAssertEqual(example.label, "J j")
        attachScreenshot(app, name: "Generated J j descender and dot")
    }

    private func launch(language: String, pack: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestDisableAnalytics",
            "-hasCompletedOnboarding", "YES", "-appLanguage", language,
            "-appLanguageWasSelectedByUser", "YES", "-ttsEnabled", "NO", "-ttsDefaultSet", "YES"
        ]
        if let pack { app.launchArguments += ["-uiTestSelectedPack", pack] }
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
