# Hookshot Hero V1 UI consistency and release QA

Review date: October 12, 2026. Baseline: main after PR #136.

Status: **source review complete; release validation remains open**. This environment is Linux. `xcodebuild -version` returned exit 127 (`xcodebuild: command not found`); Swift and Simulator are also unavailable. Source checks are not substitutes for executed builds, tests, screenshots or assistive-technology testing.

## Screens Reviewed

Reviewed source for Main Menu, Level Select, gameplay HUD, joystick, Grapple, pause, dialogue, feedback, level loading, Settings, Help, Privacy Policy, Support, Credits & Licenses, Victory, Game Over, loading failure and session unavailable. No rendered screen was reviewed in this environment.

## Main Menu Hero Verification

The existing primary-icon lookup is production code, outside DEBUG guards. Its image is cached once, scaled to fit, given conventional rounded icon corners, and hidden from accessibility. The scope symbol is a lookup-failure fallback. No icon/catalog file or binary resource was copied, added or modified.

The static blurred glow was replaced with a radial gradient. Loading, visual sharpness, correct corner cropping and Release behavior are **NOT VERIFIED**. The original 1024 marketing image is present in the source catalog, but that does not establish its availability at runtime. An installed primary-icon representation may be substantially smaller than the 160–210 pt hero; inspect actual pixel dimensions and perceived sharpness on 2x/3x devices. Do not mark this requirement complete based solely on the metadata lookup or source image size.

## Design-System Consistency

Shared backgrounds, semantic fonts, spacing, surfaces, radii and native button styles are used across screens. This pass adds pressed fill/border feedback to utility buttons, level cards and information navigation rows without scaling or changing hit targets. Ending-card press/content shapes now use their hero radius. Shared disabled buttons use a subdued surface with readable text instead of fading the whole control.

Static sRGB contrast calculations passed: 35 normal semantic text/surface pairs have a minimum of 4.72:1; 15 composited pressed text/surface pairs have a minimum of 4.75:1; disabled labels have 7.03:1. These cover the audited token combinations, not every rendered pixel or system control. Card borders are intentionally decorative; they are not claimed to meet a control-boundary contrast threshold. Native disabled semantics remain intact.

## Small iPhone

**NOT EXECUTED.** Validate an available small supported portrait device, such as iPhone SE (3rd generation), 375 × 667 pt. Check Play visibility, card wrapping, HUD/board allocation, both thumb controls, overlay scrolling and result actions.

## Standard iPhone

**NOT EXECUTED.** Validate an available standard portrait device, such as iPhone 14, 390 × 844 pt. Check hierarchy, consistent margins, native navigation and normal/pressed/disabled controls.

## Large iPhone

**NOT EXECUTED.** Validate an available large portrait device, such as iPhone 15 Pro Max, 430 × 932 pt. Check bounded content widths, balanced title/result screens and control separation. Substitute installed equivalents rather than assuming these runtimes exist.

## Dynamic Type

Default, large and accessibility device validation: **NOT EXECUTED**. Source uses semantic fonts, scrollable secondary/state/modal screens, one-column accessibility level selection, a native menu picker at accessibility sizes, adaptive HUD and minimum rather than fixed row heights. Existing tests exercise large text; new hosted tests cover surface-button target preservation and label growth. These tests have not run.

## VoiceOver / Accessibility

**NOT EXECUTED** on device. Source audit confirms decorative hero/icons and the display-only board are hidden, headings expose header traits, Pause is labeled, Grapple custom actions and joystick controls remain present, modal underlays are hidden, and result stats retain label/value semantics. Existing identifiers are preserved. Native button, Toggle, Picker, NavigationLink and DisclosureGroup behavior is retained; hands-on verification remains required.

## Reduce Motion

**NOT EXECUTED** on device. New pressed feedback disables interpolation when either system or app Reduce Motion is enabled; no scale or continuous animation is added. The hero gradient is static. Existing gameplay feedback/joystick reduced-motion wiring and simulation configuration are unchanged. Loading retains the native ProgressView.

## Gameplay Control Regression

**NOT EXECUTED.** Gameplay, controller/gesture implementations, haptics, simulation timing, level transitions, pause/background behavior, dialogue routing and game data are unchanged in this pass. Existing held-movement, Grapple, cancellation, transition and lifecycle tests remain intact. Run them before release.

## Unit Tests

**NOT EXECUTED.** New tests cover composited pressed-label contrast, disabled-label contrast, surface-button minimum targets and Dynamic Type growth. Existing hosted primary-icon resolution and gameplay regression tests remain mandatory. Python source/token checks and `git diff --check` passed; they are not XCTest results.

## UI Tests

**NOT EXECUTED.** Run the complete existing suite, including settings persistence, legal navigation, Level Select, controls, pause/dialogue, actual result levels, unsupported-request Retry, Return to Menu and missing-session fixtures. No behavioral tests were removed or replaced with snapshots in this pass.

## Analyze

**NOT EXECUTED**: Xcode unavailable.

## Release Build

Debug build, Release build, unsigned archive and installed Release icon verification: **NOT EXECUTED**. Diagnostic and preview-fixture DEBUG guards remain unchanged. Follow the full Xcode validation commands in `ios/README.md`, recording actual Xcode/SDK versions, selected simulator UDIDs and exact results. The shared scheme is `HookshotHero` in `ios/HookshotHero.xcodeproj`.

## Remaining UI Issues

- Release hero loading/sharpness/cropping is unverified; available runtime resolution is an explicit open concern.
- Device matrix, rendered contrast, native interaction states, VoiceOver, Reduce Motion and full regression suites remain unverified.
- No temporary screenshots were captured, and none were committed. On macOS, capture Main Menu, Level Select, Gameplay, Pause, Settings, Help, Victory and Game Over outside the repository and compare them side by side.
- This review does not claim production readiness until the outstanding Xcode and device checks pass.

No binary files were added or modified.
