import XCTest

final class HookshotHeroUITests: XCTestCase {
  private var app: XCUIApplication!
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-persistent-state"]
    app.launchEnvironment["HOOKSHOT_LEVEL_SEED"] = "496913"
  }
  private func launch(_ extra: String? = nil) {
    if let extra { app.launchArguments.append(extra) }
    app.launch()
  }
  func testLaunchPlayPauseResumeAndReturnAccessibility() {
    launch()
    XCTAssertTrue(app.staticTexts["Hookshot Hero"].waitForExistence(timeout: 5))
    app.buttons["playButton"].tap()
    XCTAssertTrue(app.otherElements["gameplayHUD"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["healthValue"].exists)
    XCTAssertTrue(app.staticTexts["scoreValue"].exists)
    XCTAssertTrue(app.buttons["moveUpButton"].exists)
    XCTAssertTrue(app.buttons["grappleButton"].exists)
    app.buttons["moveUpButton"].tap()
    app.buttons["pauseButton"].tap()
    XCTAssertTrue(app.staticTexts["pauseOverlay"].exists)
    XCTAssertTrue(app.buttons["overlayResumeButton"].exists)
    app.buttons["overlayResumeButton"].tap()
    app.buttons["pauseButton"].tap()
    app.buttons["returnToMenuButton"].tap()
    XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 5))
  }
  func testSettingsAreIsolated() {
    launch()
    app.buttons["settingsButton"].tap()
    XCTAssertTrue(app.otherElements["settingsScreen"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.switches["reducedMotionToggle"].isSelected)
    app.switches["reducedMotionToggle"].tap()
    app.buttons["settingsDoneButton"].tap()
  }
  func testDebugLevelSelectIsReachableAndStartsLevelFive() {
    launch()
    let levelSelect = app.buttons["debugLevelSelectButton"]
    XCTAssertTrue(levelSelect.waitForExistence(timeout: 5))
    levelSelect.tap()
    app.buttons["debugLevel5Button"].tap()
    XCTAssertTrue(app.otherElements["gameplayHUD"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Level 5"].exists)
  }
  func testDebugLevelSelectStartsLevelSixWithControls() {
    launch()
    app.buttons["debugLevelSelectButton"].tap()
    app.buttons["debugLevel6Button"].tap()
    XCTAssertTrue(app.otherElements["gameplayHUD"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Level 6"].exists)
    XCTAssertTrue(app.staticTexts["healthValue"].exists)
    XCTAssertTrue(app.staticTexts["scoreValue"].exists)
    XCTAssertTrue(app.buttons["moveUpButton"].isEnabled)
    XCTAssertTrue(app.buttons["grappleButton"].isEnabled)
  }
  func testDebugLevelSelectStartsLevelSevenAndMovesOneCell() {
    launch()
    app.buttons["debugLevelSelectButton"].tap()
    app.buttons["debugLevel7Button"].tap()
    XCTAssertTrue(app.otherElements["gameplayHUD"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Level 7"].exists)
    XCTAssertTrue(app.buttons["moveUpButton"].isEnabled)
    XCTAssertTrue(app.buttons["grappleButton"].isEnabled)
    let coordinate = app.staticTexts["playerPosition"]
    XCTAssertTrue(coordinate.waitForExistence(timeout: 5))
    XCTAssertEqual(position(coordinate), [53, 27])
    app.buttons["moveDownButton"].tap()
    XCTAssertTrue(waitForPosition(coordinate, [54, 27]))
    XCTAssertFalse(app.staticTexts["Unable to Load Level"].exists)
  }
  func testForcedWinAndResultsReturn() {
    assertForcedResult("--force-game-outcome=win", title: "Victory")
  }
  func testForcedLossAndResultsReturn() {
    assertForcedResult("--force-game-outcome=loss", title: "Game Over")
  }
  func testAccessibilityDynamicTypeKeepsPauseReachable() {
    app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
      "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    launch()
    app.buttons["playButton"].tap()
    XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["pauseButton"].isHittable)
  }
  func testSecondGameStartsClean() {
    launch()
    app.buttons["playButton"].tap()
    app.buttons["pauseButton"].tap()
    app.buttons["returnToMenuButton"].tap()
    app.buttons["playButton"].tap()
    XCTAssertTrue(app.staticTexts["scoreValue"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["scoreValue"].value as? String, "0")
    XCTAssertEqual(app.staticTexts["healthValue"].value as? String, "3")
  }
  func testDirectionTapMovesExactlyOneCellAndDoesNotRepeat() {
    launch()
    app.buttons["playButton"].tap()
    let coordinate = app.staticTexts["playerPosition"]
    XCTAssertTrue(coordinate.waitForExistence(timeout: 5))
    XCTAssertEqual(position(coordinate), [50, 27])
    app.buttons["moveUpButton"].tap()
    XCTAssertTrue(waitForPosition(coordinate, [49, 27]))
    Thread.sleep(forTimeInterval: 0.4)
    XCTAssertEqual(position(coordinate), [49, 27])
  }
  func testDirectionHoldRepeatsAndStopsWithoutReleaseStep() {
    launch()
    app.buttons["playButton"].tap()
    let coordinate = app.staticTexts["playerPosition"]
    XCTAssertTrue(coordinate.waitForExistence(timeout: 5))
    app.buttons["moveLeftButton"].press(forDuration: 0.8)
    let released = position(coordinate)
    XCTAssertEqual(released.first, 50)
    XCTAssertLessThan(released.last ?? 27, 26)
    Thread.sleep(forTimeInterval: 0.4)
    XCTAssertEqual(position(coordinate), released)
  }
  func testPausedDirectionControlsAreSemanticallyDisabledAndReenable() {
    launch()
    app.buttons["playButton"].tap()
    let coordinate = app.staticTexts["playerPosition"]
    XCTAssertTrue(coordinate.waitForExistence(timeout: 5))
    app.buttons["pauseButton"].tap()
    for id in ["moveUpButton", "moveDownButton", "moveLeftButton", "moveRightButton"] {
      XCTAssertTrue(app.buttons[id].exists)
      XCTAssertFalse(app.buttons[id].isEnabled)
    }
    let paused = position(coordinate)
    app.buttons["moveUpButton"].tap()
    XCTAssertEqual(position(coordinate), paused)
    app.buttons["overlayResumeButton"].tap()
    XCTAssertTrue(app.buttons["moveUpButton"].isEnabled)
    app.buttons["moveUpButton"].tap()
    XCTAssertTrue(waitForPosition(coordinate, [49, 27]))
  }
  func testDialogueDisablesMovementAndGrappleThenReenablesControls() {
    launch()
    app.buttons["playButton"].tap()
    for _ in 0..<2 { app.buttons["moveRightButton"].tap() }
    for _ in 0..<5 { app.buttons["moveUpButton"].tap() }
    XCTAssertTrue(app.staticTexts["chestDialogue"].waitForExistence(timeout: 5))
    for id in [
      "moveUpButton", "moveDownButton", "moveLeftButton", "moveRightButton", "grappleButton",
    ] {
      XCTAssertTrue(app.buttons[id].exists)
      XCTAssertFalse(app.buttons[id].isEnabled)
    }
    app.buttons["dialogueContinueButton"].tap()
    XCTAssertTrue(app.buttons["moveUpButton"].isEnabled)
    XCTAssertTrue(app.buttons["grappleButton"].isEnabled)
  }
  private func position(_ element: XCUIElement) -> [Int] {
    element.label.split(separator: " ").compactMap { Int($0) }
  }
  private func waitForPosition(_ element: XCUIElement, _ expected: [Int]) -> Bool {
    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline {
      if position(element) == expected { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    return false
  }
  private func assertForcedResult(_ argument: String, title: String) {
    launch(argument)
    app.buttons["playButton"].tap()
    XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["resultsTitle"].label, title)
    XCTAssertEqual(app.staticTexts["resultsScore"].label, "Final score")
    XCTAssertEqual(app.buttons["resultsReturnToMenuButton"].label, "Return to Main Menu")
    XCTAssertTrue(app.buttons["resultsReturnToMenuButton"].isHittable)
    app.buttons["resultsReturnToMenuButton"].tap()
    XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 5))
  }
}
