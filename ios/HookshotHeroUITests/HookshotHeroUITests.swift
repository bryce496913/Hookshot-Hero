import XCTest

final class HookshotHeroUITests: XCTestCase {
  private let levelFiveLeftStart = [9, 7]
  private let levelSixBottomStart = [53, 29]
  private let levelEightBottomStart = [54, 29]
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
  func testFreshMenuHidesLevelSelectAndKeepsNormalActions() {
    launch()
    XCTAssertTrue(app.staticTexts["Hookshot Hero"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["levelSelectButton"].exists)
    for identifier in ["playButton", "highScoresButton", "settingsButton", "helpButton"] {
      XCTAssertTrue(app.buttons[identifier].exists)
      XCTAssertTrue(app.buttons[identifier].isHittable)
    }
  }

  func testUnlockedMenuShowsLevelSelectAndPersistsAcrossRelaunchWithoutReseeding() {
    launch("--unlock-level-select")
    XCTAssertTrue(app.buttons["levelSelectButton"].waitForExistence(timeout: 5))
    for identifier in ["playButton", "highScoresButton", "settingsButton", "helpButton"] {
      XCTAssertTrue(app.buttons[identifier].exists)
    }
    tapScrollable(app.buttons["levelSelectButton"])
    for number in 1...12 {
      scrollTo(app.buttons["level\(number)Button"])
      XCTAssertTrue(app.buttons["level\(number)Button"].exists)
    }
    app.navigationBars.buttons.firstMatch.tap()
    app.terminate()
    app.launchArguments.removeAll { $0 == "--reset-persistent-state" || $0 == "--unlock-level-select" }
    app.launch()
    XCTAssertTrue(app.buttons["levelSelectButton"].waitForExistence(timeout: 5))
  }

  func testHighScoresOpensEmptyBoardBeforeLevelSelectUnlock() {
    launch()
    XCTAssertFalse(app.buttons["levelSelectButton"].exists)
    tapScrollable(app.buttons["highScoresButton"])
    XCTAssertTrue(app.descendants(matching: .any)["highScoresScreen"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["No scores yet."].exists)
    XCTAssertTrue(app.staticTexts["Finish a game and enter your initials to set your first high score."].exists)
    XCTAssertFalse(app.otherElements["highScoreRow1"].exists)
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertFalse(app.buttons["levelSelectButton"].exists)
    XCTAssertTrue(app.buttons["playButton"].exists)
  }

  func testHighScoresOneEntryShowsDistinctScoresAndPersistsWithoutReseeding() {
    launch("--high-scores-fixture=one")
    tapScrollable(app.buttons["highScoresButton"])
    let row = app.descendants(matching: .any)["highScoreRow1"]
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertEqual(row.label, "Rank 1. TST. Victory. Final score 1300. Game score 100. Time bonus 1200. Time 20 minutes.")
    XCTAssertFalse(app.descendants(matching: .any)["highScoreRow2"].exists)
    app.terminate()
    app.launchArguments.removeAll { $0 == "--reset-persistent-state" || $0 == "--high-scores-fixture=one" }
    app.launch()
    XCTAssertFalse(app.buttons["levelSelectButton"].exists)
    tapScrollable(app.buttons["highScoresButton"])
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertEqual(row.label, "Rank 1. TST. Victory. Final score 1300. Game score 100. Time bonus 1200. Time 20 minutes.")
  }

  func testHighScoresTenEntriesKeepRankingAndScrollAtAccessibleTextSize() {
    app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
      "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    launch("--high-scores-fixture=ten")
    tapScrollable(app.buttons["highScoresButton"])
    for rank in 1...10 {
      let row = app.descendants(matching: .any)["highScoreRow\(rank)"]
      scrollTo(row)
      let index = 11 - rank
      let raw = index * 100
      let seconds = (11 - index) * 120
      let bonus = (3600 - seconds) / 2
      XCTAssertTrue(row.label.contains("Rank \(rank). TST. Victory. Final score \(raw + bonus). Game score \(raw). Time bonus \(bonus)."))
      XCTAssertGreaterThanOrEqual(row.frame.minX, app.windows.firstMatch.frame.minX)
      XCTAssertLessThanOrEqual(row.frame.maxX, app.windows.firstMatch.frame.maxX)
    }
    XCTAssertFalse(app.descendants(matching: .any)["highScoreRow11"].exists)
  }

  func testLevelSelectHeroWelcomeVictoryDoesNotPopulateHighScores() {
    app.launchArguments.append("--unlock-level-select")
    launch("--force-game-outcome=win")
    tapScrollable(app.buttons["levelSelectButton"])
    tapLevelCard("level12Button")
    XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["resultsTimeBonus"].exists)
    XCTAssertFalse(app.staticTexts["resultsFinalScore"].exists)
    XCTAssertFalse(app.staticTexts["resultsRankingStatus"].exists)
    tapScrollable(app.buttons["resultsReturnToMenuButton"])
    tapScrollable(app.buttons["highScoresButton"])
    XCTAssertTrue(app.staticTexts["No scores yet."].waitForExistence(timeout: 5))
  }

  func testQualifyingLossRequiresThreeLettersAndPersistsSubmittedInitials() {
    launch("--score-results-fixture=qualifying")
    XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["resultsTitle"].label, "Game Over")
    scrollTo(app.textFields["highScoreInitialsEntry"])
    let field = app.textFields["highScoreInitialsEntry"]
    XCTAssertTrue(field.exists)
    for index in 1...3 { XCTAssertTrue(app.staticTexts["highScoreInitial\(index)"].exists) }
    XCTAssertEqual(app.staticTexts["highScoreProvisionalRank"].label, "Provisional rank 1")
    let save = app.buttons["highScoreSubmitButton"]
    XCTAssertFalse(save.isEnabled)
    field.tap()
    field.typeText("ab")
    XCTAssertFalse(save.isEnabled)
    field.typeText("cdef")
    XCTAssertEqual(field.value as? String, "ABC")
    XCTAssertTrue(save.isEnabled)
    // Native Done follows the same once-only submission path as SAVE SCORE.
    app.keyboards.buttons["Done"].tap()
    XCTAssertTrue(app.staticTexts["highScoreSavedConfirmation"].waitForExistence(timeout: 5))
    XCTAssertFalse(save.exists)
    tapScrollable(app.buttons["resultsReturnToMenuButton"])
    XCTAssertFalse(app.buttons["levelSelectButton"].exists)
    tapScrollable(app.buttons["highScoresButton"])
    let row = app.descendants(matching: .any)["highScoreRow1"]
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertEqual(row.label, "Rank 1. ABC. Level 7. Final score 5000. Game score 5000. Time bonus 0. Time 1 minute 23 seconds.")
    app.terminate()
    app.launchArguments.removeAll { $0 == "--reset-persistent-state" || $0 == "--score-results-fixture=qualifying" }
    app.launch()
    tapScrollable(app.buttons["highScoresButton"])
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertTrue(row.label.contains("ABC. Level 7. Final score 5000."))
    XCTAssertFalse(app.descendants(matching: .any)["highScoreRow2"].exists)
  }

  func testQualifyingScoreDisplacesTenthAndSaveButtonSubmitsOnce() {
    app.launchArguments.append("--high-scores-fixture=ten")
    launch("--score-results-fixture=qualifying")
    let field = app.textFields["highScoreInitialsEntry"]
    scrollTo(field)
    field.tap()
    field.typeText("bry")
    tapScrollable(app.buttons["highScoreSubmitButton"])
    XCTAssertTrue(app.staticTexts["highScoreSavedConfirmation"].waitForExistence(timeout: 5))
    tapScrollable(app.buttons["resultsReturnToMenuButton"])
    tapScrollable(app.buttons["highScoresButton"])
    XCTAssertTrue(app.descendants(matching: .any)["highScoreRow1"].label.contains("BRY. Level 7."))
    let tenth = app.descendants(matching: .any)["highScoreRow10"]
    scrollTo(tenth)
    XCTAssertTrue(tenth.label.contains("Game score 200."))
    XCTAssertFalse(app.descendants(matching: .any)["highScoreRow11"].exists)
  }

  func testEleventhPlaceLossNeverOffersInitialsOrMutatesBoard() {
    launch("--score-results-fixture=nonqualifying")
    XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 5))
    scrollTo(app.staticTexts["highScoreNonQualifier"])
    XCTAssertFalse(app.textFields["highScoreInitialsEntry"].exists)
    XCTAssertFalse(app.buttons["highScoreSubmitButton"].exists)
    tapScrollable(app.buttons["resultsReturnToMenuButton"])
    tapScrollable(app.buttons["highScoresButton"])
    XCTAssertTrue(app.descendants(matching: .any)["highScoreRow1"].label.contains("TST. Victory. Final score 2740."))
    let tenth = app.descendants(matching: .any)["highScoreRow10"]
    scrollTo(tenth)
    XCTAssertTrue(tenth.label.contains("Game score 100."))
    XCTAssertFalse(app.descendants(matching: .any)["highScoreRow11"].exists)
  }

  func testReturningToMenuDiscardsUnnamedCandidate() {
    launch("--score-results-fixture=qualifying")
    XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 5))
    tapScrollable(app.buttons["resultsReturnToMenuButton"])
    tapScrollable(app.buttons["highScoresButton"])
    XCTAssertTrue(app.staticTexts["No scores yet."].waitForExistence(timeout: 5))
  }

  func testLaunchPlayPauseResumeAndReturnAccessibility() {
    launch()
    XCTAssertTrue(app.staticTexts["Hookshot Hero"].waitForExistence(timeout: 5))
    app.buttons["playButton"].tap()
    XCTAssertTrue(app.otherElements["gameplayHUD"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["healthValue"].exists)
    XCTAssertTrue(app.staticTexts["scoreValue"].exists)
    XCTAssertEqual(app.staticTexts["healthValue"].label, "Health")
    XCTAssertEqual(app.staticTexts["healthValue"].value as? String, "3")
    XCTAssertEqual(app.staticTexts["scoreValue"].label, "Score")
    XCTAssertEqual(app.buttons["pauseButton"].label, "Pause game")
    XCTAssertGreaterThanOrEqual(app.buttons["pauseButton"].frame.width, 44)
    XCTAssertGreaterThanOrEqual(app.buttons["pauseButton"].frame.height, 44)
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
  func testDisabledControlHintsLeaveAccessibleThumbControls() {
    launch()
    tapScrollable(app.buttons["settingsButton"])
    app.switches["controlHintsToggle"].tap()
    tapScrollable(app.buttons["settingsDoneButton"])
    app.buttons["playButton"].tap()
    XCTAssertTrue(app.buttons["grappleButton"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["moveControlHint"].exists)
    XCTAssertFalse(app.staticTexts["grappleControlHint"].exists)
    XCTAssertTrue(app.otherElements["movementJoystick"].isHittable)
    XCTAssertEqual(app.buttons["grappleButton"].label, "Fire grapple")
    XCTAssertTrue(app.buttons["grappleButton"].isHittable)
  }

  func testLoadingPresentationIsDetectableAndBlocksUnderlyingControls() {
    launch("--preview-level-loading-overlay")
    app.buttons["playButton"].tap()
    let loading = app.staticTexts["levelLoadingOverlay"]
    XCTAssertTrue(loading.waitForExistence(timeout: 5))
    XCTAssertEqual(loading.label, "Entering Level 7")
    XCTAssertFalse(app.buttons["grappleButton"].isHittable)
    XCTAssertFalse(app.otherElements["movementJoystick"].isHittable)
  }

  func testDesignSystemButtonsKeepNativeSemanticsAndMinimumTargets() {
    app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
      "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    launch()
    let scroll = app.scrollViews.firstMatch
    for identifier in ["playButton", "highScoresButton", "settingsButton", "helpButton"] {
      let button = app.buttons[identifier]
      XCTAssertTrue(button.waitForExistence(timeout: 5))
      for _ in 0..<8 where !button.isHittable { scroll.swipeUp() }
      XCTAssertTrue(button.isHittable)
      XCTAssertGreaterThanOrEqual(button.frame.width, 44)
      XCTAssertGreaterThanOrEqual(button.frame.height, 44)
      XCTAssertFalse(button.label.isEmpty)
    }
    tapScrollable(app.buttons["helpButton"])
    XCTAssertTrue(app.staticTexts.matching(identifier: "Help").firstMatch.waitForExistence(timeout: 5))
  }

  func testReleaseMenuOmitsDevelopmentCopy() {
    launch()
    XCTAssertTrue(app.staticTexts["Hookshot Hero"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Native iOS development build"].exists)
  }
  func testMusicAndSoundEffectsDefaultOnAndPersistIndependently() {
    launch()
    tapScrollable(app.buttons["settingsButton"])
    let music = app.switches["musicToggle"], effects = app.switches["soundEffectsToggle"]
    scrollTo(music)
    XCTAssertEqual(music.value as? String, "1")
    scrollTo(effects)
    XCTAssertEqual(effects.value as? String, "1")
    tapScrollable(music)
    XCTAssertEqual(effects.value as? String, "1")
    tapScrollable(effects)
    tapScrollable(app.buttons["settingsDoneButton"])
    app.terminate()
    app.launchArguments.removeAll { $0 == "--reset-persistent-state" }
    app.launch()
    tapScrollable(app.buttons["settingsButton"])
    scrollTo(music)
    XCTAssertEqual(music.value as? String, "0")
    scrollTo(effects)
    XCTAssertEqual(effects.value as? String, "0")
  }

  func testSettingsAreIsolated() {
    launch()
    tapScrollable(app.buttons["settingsButton"])
    XCTAssertTrue(app.descendants(matching: .any)["settingsScreen"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.switches["reducedMotionToggle"].isSelected)
    app.switches["reducedMotionToggle"].tap()
    tapScrollable(app.buttons["settingsDoneButton"])
  }
  func testCreditsAndLicensesAreReachableFromSettings() {
    launch()
    tapScrollable(app.buttons["settingsButton"])
    app.scrollViews.firstMatch.swipeUp()
    let link = app.buttons["creditsLicensesLink"]
    XCTAssertTrue(link.waitForExistence(timeout: 5))
    tapScrollable(link)
    XCTAssertTrue(app.descendants(matching: .any)["creditsLicensesScreen"].waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Spinning Gold Coin"))
        .firstMatch.exists)
    tapScrollable(app.descendants(matching: .any)["codeLicenseDisclosure"])
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Permission is hereby granted"))
      .firstMatch.exists)
  }
  func testSettingsLinksToScrollablePrivacyPolicyAndSupport() {
    launch()
    tapScrollable(app.buttons["settingsButton"])
    let settings = app.scrollViews.firstMatch
    settings.swipeUp()
    scrollTo(app.staticTexts["settingsVersionInformation"])
    XCTAssertTrue(app.staticTexts["settingsVersionInformation"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["settingsVersionInformation"].label, "Version 1.0.0 (1)")
    let privacyLink = app.buttons["privacyPolicyLink"]
    XCTAssertTrue(privacyLink.waitForExistence(timeout: 5))
    tapScrollable(privacyLink)
    XCTAssertTrue(app.descendants(matching: .any)["privacyPolicyScreen"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Information collection"].exists)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    settings.swipeUp()
    tapScrollable(app.buttons["supportLink"])
    XCTAssertTrue(app.descendants(matching: .any)["supportScreen"].waitForExistence(timeout: 5))
    scrollTo(app.staticTexts["appVersionInformation"])
    XCTAssertTrue(app.staticTexts["appVersionInformation"].exists)
    XCTAssertFalse(app.links["externalSupportLink"].exists)
  }
  func testHelpLinksToPrivacyPolicy() {
    launch()
    tapScrollable(app.buttons["helpButton"])
    let help = app.scrollViews.firstMatch
    for _ in 0..<12 where !app.buttons["helpPrivacyPolicyLink"].isHittable { help.swipeUp() }
    XCTAssertTrue(app.buttons["helpPrivacyPolicyLink"].waitForExistence(timeout: 5))
    app.buttons["helpPrivacyPolicyLink"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["privacyPolicyScreen"].waitForExistence(timeout: 5))
  }
  func testHelpContainsGameWideReleaseGuidanceAndRemainsScrollable() {
    app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
      "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    launch()
    tapScrollable(app.buttons["helpButton"])
    let help = app.scrollViews.firstMatch
    XCTAssertTrue(help.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Controls"].exists)
    XCTAssertFalse(app.staticTexts["Level 1 controls"].exists)
    for identifier in [
      "helpMovementSection", "helpGrappleSection", "helpHazardsSection", "helpItemsSection",
      "helpEnemiesSection", "helpProgressionSection", "helpFinalRouteSection", "helpPauseSection",
    ] {
      for _ in 0..<12 where !app.otherElements[identifier].isHittable { help.swipeUp() }
      XCTAssertTrue(app.otherElements[identifier].exists)
    }
    help.swipeUp()
    XCTAssertTrue(app.buttons["helpPrivacyPolicyLink"].waitForExistence(timeout: 5))
    scrollTo(app.buttons["helpDoneButton"])
    XCTAssertTrue(app.buttons["helpDoneButton"].isHittable)
  }
  func testHelpIncludesJavaStoryIntro() {
    launch()
    tapScrollable(app.buttons["helpButton"])
    XCTAssertTrue(app.otherElements["storyIntro"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["The Story"].exists)
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Eldoria")).firstMatch
        .exists)
  }
  func testLeftHandedLayoutSwapsControlsWithoutChangingAccessibilityIdentity() {
    launch()
    tapScrollable(app.buttons["settingsButton"])
    XCTAssertTrue(app.otherElements["controlLayoutPicker"].waitForExistence(timeout: 5))
    app.buttons["Left-Handed"].tap()
    tapScrollable(app.buttons["settingsDoneButton"])
    app.buttons["playButton"].tap()

    let joystick = app.otherElements["movementJoystick"]
    let grapple = app.buttons["grappleButton"]
    XCTAssertTrue(joystick.waitForExistence(timeout: 5))
    XCTAssertTrue(grapple.waitForExistence(timeout: 5))
    XCTAssertGreaterThan(joystick.frame.minX, grapple.frame.minX)
    XCTAssertEqual(joystick.frame.width, grapple.frame.width, accuracy: 1)
    XCTAssertEqual(joystick.frame.height, grapple.frame.height, accuracy: 1)
    XCTAssertFalse(joystick.frame.intersects(grapple.frame))
    XCTAssertEqual(joystick.label, "Movement joystick")
    XCTAssertEqual(grapple.label, "Fire grapple")
  }
  func testLevelSelectIsReachableAndStartsLevelFive() {
    app.launchArguments.append("--unlock-level-select")
    launch()
    let levelSelect = app.buttons["levelSelectButton"]
    XCTAssertTrue(levelSelect.waitForExistence(timeout: 5))
    levelSelect.tap()
    tapLevelCard("level5Button")
    XCTAssertTrue(app.otherElements["gameplayHUD"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Level 5"].exists)
    let coordinate = app.staticTexts["playerPosition"]
    XCTAssertTrue(coordinate.waitForExistence(timeout: 5))
    XCTAssertEqual(position(coordinate), levelFiveLeftStart)
  }
  func testLevelSelectStartsLevelSixWithControls() {
    app.launchArguments.append("--unlock-level-select")
    launch()
    tapScrollable(app.buttons["levelSelectButton"])
    tapLevelCard("level6Button")
    XCTAssertTrue(app.otherElements["gameplayHUD"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Level 6"].exists)
    XCTAssertTrue(app.staticTexts["healthValue"].exists)
    XCTAssertTrue(app.staticTexts["scoreValue"].exists)
    XCTAssertTrue(app.buttons["moveUpButton"].isEnabled)
    XCTAssertTrue(app.buttons["grappleButton"].isEnabled)
    let coordinate = app.staticTexts["playerPosition"]
    XCTAssertTrue(coordinate.waitForExistence(timeout: 5))
    XCTAssertEqual(position(coordinate), levelSixBottomStart)
  }
  func testLevelFourRightExitReplacesSceneAndLoadsPlayableLevelFive() {
    assertLevelFourTransition(
      fixture: "--level-four-transition=right", movementButton: "moveRightButton",
      expectedFixture: levelFourRightFixture, destination: "Level 5",
      expectedStart: levelFiveLeftStart, playableMoveButton: "moveRightButton",
      expectedMovedPosition: [9, 8])
  }
  func testLevelFourTopExitReplacesSceneAndLoadsPlayableLevelSix() {
    assertLevelFourTransition(
      fixture: "--level-four-transition=top", movementButton: "moveUpButton",
      expectedFixture: levelFourTopFixture, destination: "Level 6",
      expectedStart: levelSixBottomStart, playableMoveButton: "moveRightButton",
      expectedMovedPosition: [53, 30])
  }
  func testLevelSelectStartsLevelSevenAndMovesOneCell() {
    app.launchArguments.append("--unlock-level-select")
    launch()
    tapScrollable(app.buttons["levelSelectButton"])
    tapLevelCard("level7Button")
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
  func testLevelSelectStartsLevelEightAtSafeBottomEntry() {
    app.launchArguments.append("--unlock-level-select")
    launch()
    tapScrollable(app.buttons["levelSelectButton"])
    tapLevelCard("level8Button")
    XCTAssertTrue(app.otherElements["gameplayHUD"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Level 8"].exists)
    let coordinate = app.staticTexts["playerPosition"]
    XCTAssertTrue(coordinate.waitForExistence(timeout: 5))
    XCTAssertEqual(position(coordinate), levelEightBottomStart)
    app.buttons["moveUpButton"].tap()
    XCTAssertTrue(waitForPosition(coordinate, [53, 29]))
    XCTAssertFalse(app.staticTexts["Unable to Load Level"].exists)
  }
  func testLoadingFailureRetryPreservesRequestAndReturnWorks() throws {
    #if DEBUG
    launch("--preview-loading-failure")
    XCTAssertTrue(app.staticTexts["Unable to Load Level"].waitForExistence(timeout: 5))
    let requested = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "ui-test-unsupported-level")).firstMatch
    XCTAssertTrue(requested.exists)
    XCTAssertEqual(app.staticTexts["loadingFailureDiagnosticCode"].label, "Diagnostic code: unsupported-level")
    tapScrollable(app.buttons["retryLevelButton"])
    XCTAssertTrue(app.staticTexts["Unable to Load Level"].waitForExistence(timeout: 5))
    XCTAssertTrue(requested.exists)
    XCTAssertFalse(app.otherElements["gameplayHUD"].exists)
    tapScrollable(app.buttons["loadingFailureMenuButton"])
    XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["loadingFailureDiagnosticCode"].exists)
    #else
    throw XCTSkip("The loading failure fixture is DEBUG-only; inspect diagnostic absence in Release manually.")
    #endif
  }

  func testUnavailableSessionReturnsWithoutStartingAnotherLevel() throws {
    #if DEBUG
    launch("--preview-session-unavailable")
    XCTAssertTrue(app.staticTexts["Session unavailable"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.otherElements["gameplayHUD"].exists)
    tapScrollable(app.buttons["sessionUnavailableMenuButton"])
    XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.otherElements["gameplayHUD"].exists)
    #else
    throw XCTSkip("The session-unavailable fixture is DEBUG-only.")
    #endif
  }

  func testAccessibleVictoryKeepsStatsAndReturnReachable() {
    app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
      "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    app.launchEnvironment["HOOKSHOT_START_LEVEL"] = "hero-welcome"
    launch("--force-game-outcome=win")
    app.buttons["playButton"].tap()
    XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["resultsLevel"].label, "Hero's Welcome")
    scrollTo(app.staticTexts["resultsScore"])
    XCTAssertTrue(app.staticTexts["resultsScore"].isHittable)
    scrollTo(app.staticTexts["resultsTime"])
    XCTAssertTrue(app.staticTexts["resultsTime"].isHittable)
    XCTAssertFalse(app.staticTexts["seconds"].exists)
    XCTAssertLessThanOrEqual(app.staticTexts["resultsTime"].frame.height,
                            app.staticTexts["resultsScore"].frame.height + 1)
    tapScrollable(app.buttons["resultsReturnToMenuButton"])
    XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 5))
  }

  func testForcedWinAndResultsReturn() {
    assertForcedResult("--force-game-outcome=win", title: "Victory")
  }
  func testForcedLossAndResultsReturn() {
    assertForcedResult("--force-game-outcome=loss", title: "Game Over")
  }
  func testWonResultsDisplayTheirActualLevel() {
    assertResultLevels(
      outcomeArgument: "--force-game-outcome=win", title: "Victory",
      levels: [
        ("level-1", "Level 1"),
        ("level-7", "Level 7"),
        ("level-10", "Level 10"),
        ("country-road", "Country Road"),
        ("hero-welcome", "Hero's Welcome"),
      ])
  }
  func testLostResultsDisplayTheirActualLevel() {
    assertResultLevels(
      outcomeArgument: "--force-game-outcome=loss", title: "Game Over",
      levels: [
        ("level-1", "Level 1"),
        ("level-7", "Level 7"),
        ("level-10", "Level 10"),
        ("country-road", "Country Road"),
        ("hero-welcome", "Hero's Welcome"),
      ])
  }
  func testAccessibilityDynamicTypeKeepsPauseReachable() {
    app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
      "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    launch()
    app.buttons["playButton"].tap()
    XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["pauseButton"].isHittable)
    let window = app.windows.firstMatch.frame
    for identifier in ["healthValue", "scoreValue", "levelTitle"] {
      let stat = app.staticTexts[identifier]
      XCTAssertTrue(stat.isHittable)
      XCTAssertGreaterThanOrEqual(stat.frame.minX, window.minX)
      XCTAssertLessThanOrEqual(stat.frame.maxX, window.maxX)
    }
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

    XCTAssertTrue(abs(joystick.frame.width - 132) < 1 || abs(joystick.frame.width - 148) < 1)
    XCTAssertEqual(joystick.frame.width, joystick.frame.height, accuracy: 1)
    XCTAssertEqual(grapple.frame.width, joystick.frame.width, accuracy: 1)
    XCTAssertEqual(grapple.frame.height, joystick.frame.height, accuracy: 1)
    XCTAssertFalse(joystick.frame.intersects(grapple.frame))
    XCTAssertFalse(board.frame.intersects(dock.frame))
    let minimumGap: CGFloat = joystick.frame.width < 140 ? 16 : 24
    XCTAssertGreaterThanOrEqual(grapple.frame.minX - joystick.frame.maxX, minimumGap)
    let window = app.windows.firstMatch.frame
    XCTAssertGreaterThanOrEqual(joystick.frame.minX, window.minX)
    XCTAssertLessThanOrEqual(grapple.frame.maxX, window.maxX)
    XCTAssertGreaterThanOrEqual(board.frame.width, 240)
    XCTAssertGreaterThanOrEqual(board.frame.height, 240)
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
    XCTAssertGreaterThanOrEqual(joystick.frame.width, 132)
    XCTAssertEqual(joystick.frame.width, grapple.frame.width, accuracy: 1)
    XCTAssertEqual(joystick.frame.height, grapple.frame.height, accuracy: 1)
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
    expectedStart: [Int], playableMoveButton: String, expectedMovedPosition: [Int],
    file: StaticString = #filePath, line: UInt = #line
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
      waitForPosition(destinationPosition, expectedMovedPosition),
      "Player did not finish the verified safe movement in \(destination)", file: file, line: line)
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

  func testPauseAndDialogueDisableJoystick() {
    launch()
    app.buttons["playButton"].tap()
    let joystick = app.otherElements["movementJoystick"]
    XCTAssertTrue(joystick.waitForExistence(timeout: 5))
    app.buttons["pauseButton"].tap()
    XCTAssertFalse(joystick.isHittable)
    app.buttons["overlayResumeButton"].tap()
    XCTAssertTrue(joystick.isEnabled)

    for _ in 0..<2 { app.buttons["moveRightButton"].tap() }
    for _ in 0..<5 { app.buttons["moveUpButton"].tap() }
    XCTAssertTrue(app.staticTexts["chestDialogue"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["chestDialogue"].label, "Message")
    XCTAssertFalse(app.staticTexts["Talking Chest"].exists)
    XCTAssertFalse(joystick.isHittable)
  }
  func testPauseBlocksUnderlyingControlsAndReenablesMovement() {
    launch()
    app.buttons["playButton"].tap()
    let coordinate = app.staticTexts["playerPosition"]
    XCTAssertTrue(coordinate.waitForExistence(timeout: 5))
    let beforePause = position(coordinate)
    app.buttons["pauseButton"].tap()
    XCTAssertTrue(app.buttons["overlayResumeButton"].isHittable)
    for id in ["moveUpButton", "moveDownButton", "moveLeftButton", "moveRightButton", "grappleButton"] {
      XCTAssertFalse(app.buttons[id].isHittable)
    }
    app.buttons["overlayResumeButton"].tap()
    XCTAssertEqual(position(coordinate), beforePause)
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
      XCTAssertFalse(app.buttons[id].isHittable)
    }
    XCTAssertEqual(app.staticTexts["chestDialogue"].label, "Message")
    XCTAssertTrue(app.buttons["dialogueContinueButton"].isHittable)
    app.buttons["dialogueContinueButton"].tap()
    XCTAssertTrue(app.buttons["moveUpButton"].isEnabled)
    XCTAssertTrue(app.buttons["grappleButton"].isEnabled)
  }
  private func scrollTo(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let scroll = app.scrollViews.firstMatch
    for _ in 0..<24 {
      if element.exists && element.isHittable { return }
      if element.exists {
        let frame = element.frame
        if frame.height > 0 && frame.maxY < scroll.frame.minY {
          scroll.swipeDown()
        } else {
          scroll.swipeUp()
        }
      } else {
        scroll.swipeUp()
      }
    }
    XCTFail("Element must be reachable by scrolling", file: file, line: line)
  }

  private func tapScrollable(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    scrollTo(element, file: file, line: line)
    element.tap()
  }

  func testAccessibleSettingsKeepNativeLayoutSelectionAndInformationReachable() {
    app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
      "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    launch()
    tapScrollable(app.buttons["settingsButton"])
    tapScrollable(app.descendants(matching: .any)["controlLayoutPicker"])
    app.buttons["Left-Handed"].tap()
    tapScrollable(app.buttons["supportLink"])
    XCTAssertTrue(app.descendants(matching: .any)["supportScreen"].waitForExistence(timeout: 5))
    scrollTo(app.staticTexts["appVersionInformation"])
    XCTAssertTrue(app.staticTexts["appVersionInformation"].isHittable)
    XCTAssertFalse(app.links["externalSupportLink"].exists)
    app.navigationBars.buttons.firstMatch.tap()
    tapScrollable(app.buttons["privacyPolicyLink"])
    XCTAssertTrue(app.descendants(matching: .any)["privacyPolicyScreen"].waitForExistence(timeout: 5))
    let supportHeading = app.staticTexts["Support and contact"]
    scrollTo(supportHeading)
    XCTAssertTrue(supportHeading.isHittable)
  }

  func testSettingsPersistAndHelpReturnsToSettings() {
    launch()
    tapScrollable(app.buttons["settingsButton"])
    app.switches["reducedMotionToggle"].tap()
    app.switches["controlHintsToggle"].tap()
    tapScrollable(app.buttons["settingsHelpLink"])
    XCTAssertTrue(app.staticTexts["The Story"].waitForExistence(timeout: 5))
    tapScrollable(app.buttons["helpDoneButton"])
    XCTAssertTrue(app.descendants(matching: .any)["settingsScreen"].waitForExistence(timeout: 5))
    tapScrollable(app.buttons["settingsDoneButton"])
    app.terminate()
    app.launchArguments.removeAll { $0 == "--reset-persistent-state" }
    app.launch()
    tapScrollable(app.buttons["settingsButton"])
    XCTAssertEqual(app.switches["reducedMotionToggle"].value as? String, "1")
    XCTAssertEqual(app.switches["controlHintsToggle"].value as? String, "0")
  }

  private func tapLevelCard(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
    let card = app.buttons[identifier]
    let scroll = app.scrollViews.firstMatch
    for _ in 0..<12 {
      if card.exists && card.isHittable { break }
      scroll.swipeUp()
    }
    XCTAssertTrue(card.waitForExistence(timeout: 5), file: file, line: line)
    XCTAssertTrue(card.isHittable, file: file, line: line)
    card.tap()
  }

  func testLevelSelectEndingCardsAndNativeBackNavigation() {
    app.launchArguments.append("--unlock-level-select")
    launch()
    tapScrollable(app.buttons["levelSelectButton"])
    let scroll = app.scrollViews.firstMatch
    for _ in 0..<8 {
      if app.buttons["level12Button"].isHittable { break }
      scroll.swipeUp()
    }
    XCTAssertEqual(app.buttons["level11Button"].label, "Country Road")
    XCTAssertEqual(app.buttons["level12Button"].label, "Hero's Welcome")
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 5))
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
    XCTAssertNotNil(Int(app.staticTexts["resultsScore"].value as? String ?? ""))
    XCTAssertEqual(app.staticTexts["resultsTime"].label, "Elapsed time")
    let time = app.staticTexts["resultsTime"]
    let spoken = time.value as? String ?? ""
    XCTAssertNotNil(spoken.range(of: #"^([0-9]+ minutes?( [0-9]+ seconds?)?|[0-9]+ seconds?)$"#,
                                options: .regularExpression))
    XCTAssertFalse(spoken.contains(":"), "VoiceOver should receive words rather than the visual clock")
    XCTAssertFalse(app.staticTexts["seconds"].exists, "No separate visual unit line")
    XCTAssertLessThanOrEqual(time.frame.height, app.staticTexts["resultsScore"].frame.height + 1,
                            "The timer must fit in the same single-line height as the score")
    XCTAssertEqual(app.buttons["resultsReturnToMenuButton"].label, "Return to Main Menu")
    XCTAssertTrue(app.buttons["resultsReturnToMenuButton"].isHittable)
    tapScrollable(app.buttons["resultsReturnToMenuButton"])
    XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 5))
  }
  private func assertResultLevels(
    outcomeArgument: String, title: String, levels: [(id: String, displayName: String)]
  ) {
    for level in levels {
      app = XCUIApplication()
      app.launchArguments = ["--ui-testing", "--reset-persistent-state", outcomeArgument]
      app.launchEnvironment["HOOKSHOT_LEVEL_SEED"] = "496913"
      app.launchEnvironment["HOOKSHOT_START_LEVEL"] = level.id
      app.launch()
      app.buttons["playButton"].tap()

      let levelText = app.staticTexts["resultsLevel"]
      XCTAssertTrue(
        levelText.waitForExistence(timeout: 5),
        "Expected results level accessibility element for \(level.displayName)")
      XCTAssertEqual(levelText.label, level.displayName)
      XCTAssertEqual(app.staticTexts["resultsTitle"].label, title)

      app.terminate()
    }
  }
}
