import XCTest

final class HookshotHeroUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["--ui-testing", "--reset-persistent-state"]
    }
    private func launch(_ extra: String? = nil) { if let extra { app.launchArguments.append(extra) }; app.launch() }
    func testLaunchPlayPauseResumeAndReturnAccessibility() {
        launch(); XCTAssertTrue(app.staticTexts["Hookshot Hero"].waitForExistence(timeout: 5)); app.buttons["playButton"].tap()
        XCTAssertTrue(app.otherElements["gameplayHUD"].waitForExistence(timeout: 5)); XCTAssertTrue(app.staticTexts["healthValue"].exists); XCTAssertTrue(app.staticTexts["scoreValue"].exists)
        app.buttons["pauseButton"].tap(); XCTAssertTrue(app.staticTexts["pauseOverlay"].exists); XCTAssertTrue(app.buttons["overlayResumeButton"].exists)
        app.buttons["overlayResumeButton"].tap(); app.buttons["pauseButton"].tap(); app.buttons["returnToMenuButton"].tap()
        XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 5))
    }
    func testSettingsAreIsolated() {
        launch(); app.buttons["settingsButton"].tap(); XCTAssertTrue(app.otherElements["settingsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["reducedMotionToggle"].isSelected); app.switches["reducedMotionToggle"].tap(); app.buttons["settingsDoneButton"].tap()
    }
    func testForcedWinAndResultsReturn() { assertForcedResult("--force-game-outcome=win", title: "Victory") }
    func testForcedLossAndResultsReturn() { assertForcedResult("--force-game-outcome=loss", title: "Game Over") }
    func testAccessibilityDynamicTypeKeepsPauseReachable() {
        app.launchEnvironment["UIPreferredContentSizeCategoryName"] = "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        launch(); app.buttons["playButton"].tap(); XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["pauseButton"].isHittable)
    }
    func testSecondGameStartsClean() {
        launch(); app.buttons["playButton"].tap(); app.buttons["pauseButton"].tap(); app.buttons["returnToMenuButton"].tap(); app.buttons["playButton"].tap()
        XCTAssertTrue(app.staticTexts["scoreValue"].waitForExistence(timeout: 5)); XCTAssertEqual(app.staticTexts["scoreValue"].value as? String, "0")
        XCTAssertEqual(app.staticTexts["healthValue"].value as? String, "3")
    }
    private func assertForcedResult(_ argument: String, title: String) {
        launch(argument); app.buttons["playButton"].tap(); XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 5)); XCTAssertEqual(app.staticTexts["resultsTitle"].label, title)
        XCTAssertTrue(app.buttons["resultsReturnToMenuButton"].isHittable); app.buttons["resultsReturnToMenuButton"].tap(); XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 5))
    }
}
