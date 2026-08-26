import XCTest

final class LowDopScribbleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBookshelfTitleIsVisible() throws {
        let app = XCUIApplication()
        app.launch()

        let bookshelfTitle = app.staticTexts["bookshelf.title"]
        XCTAssertTrue(bookshelfTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(bookshelfTitle.label, "Denny's ABC Tracing")
    }
}
