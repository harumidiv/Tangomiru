import XCTest

final class QuizCompletionUITests: XCTestCase {
    @MainActor
    func testDoneReturnsToPassageDetail() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshot", "library", "-quizScope", "veryWeak"]
        app.launch()

        let passage = app.staticTexts["Gardens on the Rooftops"]
        XCTAssertTrue(passage.waitForExistence(timeout: 10))
        passage.tap()

        let start = app.buttons["クイズを始める"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        let skip = app.buttons["SKIP"]
        for progress in ["1 / 2", "2 / 2"] {
            XCTAssertTrue(app.staticTexts[progress].waitForExistence(timeout: 5))
            skip.tap()
        }

        let done = app.buttons["完了"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
    }
}
