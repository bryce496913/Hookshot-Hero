# Level 4 Through Level 8 Manual Smoke-Test Report

## Environment

- Host: Ubuntu 24.04.4 LTS (`x86_64`)
- Xcode version: Unavailable; Xcode is not installed on this host.
- Device/simulator: Unavailable; no iOS Simulator or physical iPhone is attached.
- iOS version: Unavailable.
- Runnable Debug app: Not produced or supplied in this environment.

The required precondition was not met. The repository was inspected without
editing application source, but manual gameplay was not attempted because this
host cannot run the Xcode validation gate or an iOS app.

## Commit Tested

Manual testing was requested for commit
`28277bef80d514f016b5a8516c67cf961ff1cca7`. No manual test result is claimed
for that commit because the required Apple tooling and target device were
unavailable.

## Level 4 Door Rendering

Not tested. The alignment, locked state, and closed-to-open sprite replacement
for the top and right doors require visual inspection in a runnable iOS app.

## Level 4 → Level 5

Not tested. Level 5's `.left` entry, row 8/column 7 start, HUD, controls,
loading, and carryover remain unverified.

## Level 5 → Level 4

Not tested. The `.right` return entry, boss state, open doors, and completion
reward behavior remain unverified.

## Level 5 → Level 7

Not tested. Normal Level 7 loading remains unverified.

## Level 7 → Level 8

Not tested. Level 8's `.bottom` entry, ghost-chest absence, controls, enemies,
and items remain unverified.

## Level 8 → Level 7

Not tested. The Level 7 `.top` return and carryover remain unverified.

## Level 4 → Level 6

Not tested. Level 6's `.bottom` entry, row 50/column 27 start, HUD, controls,
movement persistence, lava-reset behavior, chests, and enemies remain
unverified.

## Level 6 → Level 8

Not tested. Level 8's `.left` entry at
`LevelEightDefinition.fromLevelSixStart`, loading, ghost-chest absence, and
controls remain unverified.

## Level 8 → Level 6

Not tested. Level 6's corrected `.top` return start remains unverified.

## Carryover

Not tested. Character identity, health, score, completion state, chest state,
reward uniqueness, elapsed session time, and uninterrupted connected-level
navigation remain unverified.

## Rendering

Not tested. Bottom-left anchored dynamic objects in Levels 4 through 7 require
visual inspection on an iOS target.

## Failures

### Environment blocker

- Source level: Not applicable.
- Destination level: Not applicable.
- Entry direction: Not applicable.
- Visible symptom: No runnable iOS target is available.
- Diagnostic code: None.
- Console error: `xcodebuild` and `xcrun` are not installed.
- Crash or recoverable failure: Neither; the app could not be launched.
- Reproduction: On this Ubuntu host, run `command -v xcodebuild` and
  `command -v xcrun`; neither command resolves.
- Recommended focused Codex pass: Re-run this manual-only checklist on the
  exact automated-validation commit using a macOS host with the validated
  Debug build and an iOS Simulator or attached iPhone.

No gameplay defect was observed because gameplay could not be exercised.

## Level 9 Readiness

**MANUAL VALIDATION FAILED — LEVEL 9 REMAINS BLOCKED**

## Source Changes

None. This report is documentation only.

No binary files were added or modified.
