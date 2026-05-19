import XCTest

final class LowDopamineLabyrinthUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLastLevelCompletionReturnsToBookshelf() throws {
        let app = XCUIApplication()
        app.launchArguments += [
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
