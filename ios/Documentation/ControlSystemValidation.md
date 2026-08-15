# Touch Control System Validation

Validation date: 2026-08-15

## Result

The source and test review found no substantive control defect. The Apple-toolchain portion is
**blocked by the validation host**, which is Linux and has neither `xcodebuild` nor `xcrun`.
Consequently this pass does not declare the overhaul ready: builds, tests, analysis, archive, and
on-simulator gesture behavior remain unverified until the same commands run on a macOS host with
Xcode installed.

No control features were added. The only executable change in this pass is an interleaved controller
regression that checks movement remains engaged while Grapple aims and fires, including test-double
haptic ordering.

## Regression coverage review

| Area | Automated coverage present | Status in this environment |
| --- | --- | --- |
| Movement | Dead zone, four cardinal directions, diagonal snapping, single-cell tap, hold/repeat/release, held direction changes, cancellation, Pause, dialogue, and lifecycle paths | Reviewed; not executed |
| Grapple | Facing tap, explicit drag aim, four directions, exactly-once release, cancellation, disabled/active state, maximum range, and simulation behavior | Reviewed; not executed |
| Multi-touch | Interleaved joystick engagement and Grapple aim/fire controller regression | Added; not executed. Physical gesture ownership still requires an Apple simulator/device run |
| Accessibility | Four semantic movement buttons, semantic Grapple actions, disabled states, non-drag actions, and largest Dynamic Type control reachability | Reviewed; not executed |
| Layout | Standard dock geometry and left-handed control swap | Reviewed; not executed |
| Haptics | Recording test double covers engagement, direction change, aim change, firing, and disabled/cancel behavior | Reviewed; not executed |

## Apple-toolchain validation

Simulator discovery could not begin because `xcrun` is unavailable. Every requested action was
attempted with its own DerivedData directory and exited 127 because `xcodebuild` was unavailable:

1. Debug clean build: `/tmp/hookshot-dd-debug`
2. build-for-testing: `/tmp/hookshot-dd-build-for-testing`
3. `HookshotHeroTests`: `/tmp/hookshot-dd-unit`
4. `HookshotHeroUITests`: `/tmp/hookshot-dd-ui`
5. Analyze: `/tmp/hookshot-dd-analyze`
6. Release simulator build: `/tmp/hookshot-dd-release`
7. Unsigned device archive: `/tmp/hookshot-dd-archive`

`xcodebuild -version`, `xcrun --sdk iphoneos --show-sdk-version`, and
`xcrun simctl list devices available` also exited 127. Run the matrix again on macOS before release.

## Portable checks

Swift's `plutil` successfully linted `Info.plist`, `PrivacyInfo.xcprivacy`, and `project.pbxproj`.
A repository-relative project-path existence check also passed. `git diff --check` and
`git status --short` are recorded in the change's final validation report because their output
necessarily changes as the validation record is prepared and committed.

No binary files were added or modified.
