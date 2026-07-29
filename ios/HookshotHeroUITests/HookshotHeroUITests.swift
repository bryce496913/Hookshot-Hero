import XCTest

final class HookshotHeroUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication(); app.launch() }
    func testLaunchPlayPauseResumeAndReturn() {
        XCTAssertTrue(app.staticTexts["Hookshot Hero"].waitForExistence(timeout: 5)); app.buttons["playButton"].tap()
        XCTAssertTrue(app.otherElements["gameplayScene"].waitForExistence(timeout: 5)); app.buttons["pauseButton"].tap()
        XCTAssertTrue(app.staticTexts["pauseOverlay"].exists); app.buttons["overlayResumeButton"].tap(); app.buttons["pauseButton"].tap()
        app.buttons["returnToMenuButton"].tap(); XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 5))
    }
    func testSettingsOpensAndCloses() {
        app.buttons["settingsButton"].tap(); XCTAssertTrue(app.otherElements["settingsScreen"].waitForExistence(timeout: 5))
        app.buttons["settingsDoneButton"].tap(); XCTAssertTrue(app.buttons["playButton"].exists)
    }
    func testStartingSecondSessionShowsCleanHUD() {
        app.buttons["playButton"].tap(); app.buttons["pauseButton"].tap(); app.buttons["returnToMenuButton"].tap(); app.buttons["playButton"].tap()
        XCTAssertTrue(app.staticTexts["Score 0"].waitForExistence(timeout: 5)); XCTAssertTrue(app.staticTexts["Health 3"].exists)
    }
}
