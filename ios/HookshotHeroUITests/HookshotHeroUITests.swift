import XCTest

final class HookshotHeroUITests: XCTestCase {
  private let levelFiveLeftStart = [8, 7]
  private let levelSixBottomStart = [50, 27]
  private let levelFourRightFixture = [29, 54]
  private let levelFourTopFixture = [5, 29]

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
    XCTAssertTrue(app.otherElements["movementJoystick"].exists)
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
  func testLeftHandedLayoutSwapsControlsWithoutChangingAccessibilityIdentity() {
    launch()
    app.buttons["settingsButton"].tap()
    XCTAssertTrue(app.otherElements["controlLayoutPicker"].waitForExistence(timeout: 5))
    app.buttons["Left-Handed"].tap()
    app.buttons["settingsDoneButton"].tap()
    app.buttons["playButton"].tap()

    let joystick = app.otherElements["movementJoystick"]
    let grapple = app.buttons["grappleButton"]
    XCTAssertTrue(joystick.waitForExistence(timeout: 5))
    XCTAssertTrue(grapple.waitForExistence(timeout: 5))
    XCTAssertGreaterThan(joystick.frame.minX, grapple.frame.minX)
    XCTAssertEqual(joystick.label, "Movement joystick")
    XCTAssertEqual(grapple.label, "Fire grapple")
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
  func testLevelFourRightExitReplacesSceneAndLoadsPlayableLevelFive() {
    assertLevelFourTransition(
      fixture: "--level-four-transition=right", movementButton: "moveRightButton",
      expectedFixture: levelFourRightFixture, destination: "Level 5",
      expectedStart: levelFiveLeftStart, playableMoveButton: "moveRightButton")
  }
  func testLevelFourTopExitReplacesSceneAndLoadsPlayableLevelSix() {
    assertLevelFourTransition(
      fixture: "--level-four-transition=top", movementButton: "moveUpButton",
      expectedFixture: levelFourTopFixture, destination: "Level 6",
      expectedStart: levelSixBottomStart, playableMoveButton: "moveDownButton")
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
  func testStandardPhoneControlDockIsSeparatedHittableAndSafe() {
    launch()
    app.buttons["playButton"].tap()

    let dock = app.otherElements["gameControlDock"]
    let board = app.otherElements["gameBoard"]
    let joystick = app.otherElements["movementJoystick"]
    let grapple = app.buttons["grappleButton"]
    let pause = app.buttons["pauseButton"]
    for element in [dock, board, joystick, grapple, pause] {
      XCTAssertTrue(element.waitForExistence(timeout: 5))
      XCTAssertTrue(element.isHittable)
    }

    XCTAssertGreaterThanOrEqual(joystick.frame.width, 116)
    XCTAssertGreaterThanOrEqual(joystick.frame.height, 116)
    XCTAssertGreaterThanOrEqual(grapple.frame.width, 76)
    XCTAssertGreaterThanOrEqual(grapple.frame.height, 76)
    XCTAssertFalse(joystick.frame.intersects(grapple.frame))
    XCTAssertFalse(board.frame.intersects(dock.frame))
    XCTAssertGreaterThan(grapple.frame.minX - joystick.frame.maxX, 44)
    XCTAssertGreaterThanOrEqual(app.windows.firstMatch.frame.maxY - dock.frame.maxY, 20)
  }
  func testLargestDynamicTypeKeepsBothThumbControlsHittableAndSeparated() {
    app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
      "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    launch()
    app.buttons["playButton"].tap()

    let joystick = app.otherElements["movementJoystick"]
    let grapple = app.buttons["grappleButton"]
    XCTAssertTrue(joystick.waitForExistence(timeout: 5))
    XCTAssertTrue(grapple.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["pauseButton"].isHittable)
    XCTAssertTrue(joystick.isHittable)
    XCTAssertTrue(grapple.isHittable)
    XCTAssertFalse(joystick.frame.intersects(grapple.frame))
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
  func testJoystickDragHoldDirectionChangeAndRelease() {
    launch()
    app.buttons["playButton"].tap()
    let coordinate = app.staticTexts["playerPosition"]
    XCTAssertTrue(coordinate.waitForExistence(timeout: 5))
    let joystick = app.otherElements["movementJoystick"]
    XCTAssertTrue(joystick.waitForExistence(timeout: 5))

    joystick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(
        forDuration: 0.7,
        thenDragTo: joystick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
    let afterUp = position(coordinate)
    XCTAssertLessThan(afterUp.first ?? 50, 50)
    Thread.sleep(forTimeInterval: 0.35)
    XCTAssertEqual(position(coordinate), afterUp)

    joystick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(
        forDuration: 0.2,
        thenDragTo: joystick.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.7)))
    XCTAssertGreaterThan(position(coordinate).last ?? 27, afterUp.last ?? 27)
  }

  func testTapDragAndPauseCancellationForGrapple() {
    launch()
    app.buttons["playButton"].tap()
    let grapple = app.buttons["grappleButton"]
    XCTAssertTrue(grapple.waitForExistence(timeout: 5))

    grapple.tap()
    XCTAssertTrue(waitForDisabled(grapple))
    XCTAssertTrue(waitForEnabled(grapple))

    grapple.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(
        forDuration: 0.1,
        thenDragTo: grapple.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
    XCTAssertTrue(waitForDisabled(grapple))
    XCTAssertTrue(waitForEnabled(grapple))

    app.buttons["pauseButton"].tap()
    XCTAssertFalse(grapple.isEnabled)
    app.buttons["overlayResumeButton"].tap()
    XCTAssertTrue(grapple.isEnabled)
  }

  private func assertLevelFourTransition(
    fixture: String, movementButton: String, expectedFixture: [Int], destination: String,
    expectedStart: [Int], playableMoveButton: String, file: StaticString = #filePath,
    line: UInt = #line
  ) {
    app.launchEnvironment["HOOKSHOT_START_LEVEL"] = "level-4"
    launch(fixture)

    XCTAssertTrue(app.staticTexts["Level 4"].waitForExistence(timeout: 5), file: file, line: line)
    let sourcePosition = app.staticTexts["playerPosition"]
    XCTAssertTrue(sourcePosition.waitForExistence(timeout: 5), file: file, line: line)
    XCTAssertEqual(position(sourcePosition), expectedFixture, file: file, line: line)
    XCTAssertFalse(app.staticTexts[destination].exists, file: file, line: line)
    XCTAssertFalse(app.staticTexts["Unable to Load Level"].exists, file: file, line: line)

    app.buttons[movementButton].tap()
    XCTAssertTrue(
      waitForDestinationOrFailure(destination, file: file, line: line), file: file, line: line)

    XCTAssertTrue(app.staticTexts[destination].exists, file: file, line: line)
    XCTAssertFalse(app.staticTexts["Unable to Load Level"].exists, file: file, line: line)
    XCTAssertTrue(app.otherElements["movementJoystick"].isEnabled, file: file, line: line)
    XCTAssertTrue(app.buttons["grappleButton"].isEnabled, file: file, line: line)
    let destinationPosition = app.staticTexts["playerPosition"]
    XCTAssertEqual(position(destinationPosition), expectedStart, file: file, line: line)
    app.buttons[playableMoveButton].tap()
    XCTAssertTrue(
      waitForPositionChange(destinationPosition, from: expectedStart),
      "Controls were enabled but did not move the player in \(destination)", file: file,
      line: line)
  }

  private func waitForDestinationOrFailure(
    _ destination: String, file: StaticString, line: UInt
  ) -> Bool {
    let deadline = Date().addingTimeInterval(8)
    repeat {
      if app.staticTexts[destination].exists { return true }
      if app.staticTexts["Unable to Load Level"].exists {
        reportLoadingFailure(destination, file: file, line: line)
        return false
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    } while Date() < deadline
    XCTFail("Timed out waiting for \(destination)", file: file, line: line)
    return false
  }

  private func reportLoadingFailure(
    _ destination: String, file: StaticString, line: UInt
  ) {
    let diagnostic = app.staticTexts["loadingFailureDiagnosticCode"]
    let code = diagnostic.exists ? diagnostic.label : "loadingFailureDiagnosticCode unavailable"
    XCTFail(
      "Unable to Load Level while waiting for \(destination): \(code)", file: file, line: line)
  }

  private func waitForPositionChange(_ element: XCUIElement, from initial: [Int]) -> Bool {
    let deadline = Date().addingTimeInterval(3)
    repeat {
      if position(element) != initial { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    } while Date() < deadline
    return false
  }

  func testPauseAndDialogueDisableJoystick() {
    launch()
    app.buttons["playButton"].tap()
    let joystick = app.otherElements["movementJoystick"]
    XCTAssertTrue(joystick.waitForExistence(timeout: 5))
    app.buttons["pauseButton"].tap()
    XCTAssertFalse(joystick.isEnabled)
    app.buttons["overlayResumeButton"].tap()
    XCTAssertTrue(joystick.isEnabled)

    for _ in 0..<2 { app.buttons["moveRightButton"].tap() }
    for _ in 0..<5 { app.buttons["moveUpButton"].tap() }
    XCTAssertTrue(app.staticTexts["chestDialogue"].waitForExistence(timeout: 5))
    XCTAssertFalse(joystick.isEnabled)
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
  private func waitForEnabled(_ element: XCUIElement) -> Bool {
    let deadline = Date().addingTimeInterval(3)
    while Date() < deadline {
      if element.isEnabled { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    return false
  }
  private func waitForDisabled(_ element: XCUIElement) -> Bool {
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
      if !element.isEnabled { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.02))
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
