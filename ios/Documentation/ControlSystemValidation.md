# Touch Control System Validation

Validation review date: 2026-09-03

## Result

Source and test coverage was reviewed for this documentation-only pass, and no substantive mismatch
was found between the implemented controls and the covered behavior. No Swift source or tests were
changed. Source review and the existence of tests are not evidence that those tests passed.

Apple-toolchain validation remains **outstanding**. The available host is Linux and has neither
`xcodebuild` nor `xcrun`, so this pass does not claim that Xcode builds, tests, analysis, archive, or
on-simulator gesture validation passed. Those checks still require a macOS host with Xcode installed.

## Regression coverage review

| Area | Automated coverage present | Status in this environment |
| --- | --- | --- |
| Movement | Dead zone, four cardinal directions, diagonal snapping, single-cell tap, hold/repeat/release, held direction changes, cancellation, Pause, dialogue, and lifecycle paths | Reviewed; not executed |
| Grapple | Facing tap, explicit drag aim, four directions, exactly-once release, cancellation, disabled/active state, maximum range, and simulation behavior | Reviewed; not executed |
| Multi-touch | Interleaved joystick engagement and Grapple aim/fire controller regression | Present in source; reviewed, not executed. Physical gesture ownership still requires an Apple simulator/device run |
| Accessibility | Four semantic movement buttons, semantic Grapple actions, disabled states, non-drag actions, and largest Dynamic Type control reachability | Reviewed; not executed |
| Layout | Standard dock geometry and left-handed control swap | Reviewed; not executed |
| Haptics | Recording test double covers engagement, direction change, aim change, firing, and disabled/cancel behavior | Reviewed; not executed |

## Apple-toolchain validation

The earlier validation attempt recorded by this document could not begin simulator discovery because
`xcrun` was unavailable. Its requested actions used separate DerivedData directories and exited 127
because `xcodebuild` was unavailable:

1. Debug clean build: `/tmp/hookshot-dd-debug`
2. build-for-testing: `/tmp/hookshot-dd-build-for-testing`
3. `HookshotHeroTests`: `/tmp/hookshot-dd-unit`
4. `HookshotHeroUITests`: `/tmp/hookshot-dd-ui`
5. Analyze: `/tmp/hookshot-dd-analyze`
6. Release simulator build: `/tmp/hookshot-dd-release`
7. Unsigned device archive: `/tmp/hookshot-dd-archive`

`xcodebuild -version`, `xcrun --sdk iphoneos --show-sdk-version`, and
`xcrun simctl list devices available` also exited 127 in that attempt. No later successful
Apple-toolchain run is recorded here. Run the matrix again on macOS before release.

## Portable checks

The earlier validation pass recorded successful portable `plutil` linting of `Info.plist`,
`PrivacyInfo.xcprivacy`, and `project.pbxproj`, plus a repository-relative project-path existence
check. The current documentation pass reports its own portable checks separately; these checks do
not substitute for Apple-toolchain validation.

No binary files were added or modified.
