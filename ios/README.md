# Hookshot Hero for iOS — playable Levels 1–6

The native SwiftUI/SpriteKit conversion now provides playable **Levels 1 through 6** while the Java game remains the behavioral reference. Level 4 now preserves Java's branch: its right door leads to Level 5 and its top door leads to Level 6. Level 5 ends at the future Level 7 boundary; Level 6 ends at the future Level 8 boundary.

## Current gameplay

Lidia starts on the original 60×60 board at row 50, column 27. Native direction-pad controls support tap and hold movement, and Grapple fires in her facing direction with the original 19-cell range. Walls, the six-cell top exit, the closed lower door, lava damage and safe-position restoration all participate in collision. Coins, cabbages, mines, and the talking chest are interactive. Victory, defeat, automatic results navigation, high scores, and Level 1 completion persistence are implemented.

Shared boundary geometry drives simulation and SpriteKit presentation. Device-independent collision footprints cover Lidia and every item; deterministic spawning validates the entire footprint against walls, lava, doors, the chest, start safety region, and other entities. Typed, elapsed-time feedback presents score and health changes, uses the bundled `heart.png` in the HUD, announces important events through VoiceOver, and supplies a programmatic mine explosion. Reduced Motion keeps that explosion visible but replaces scaling with an in-place fade. Chest dialogue suspends simulation and elapsed time until Continue. Health and score snapshots are published only after a value changes, so ordinary SpriteKit frames do not invalidate SwiftUI.

The existing Java sprite resources are bundled directly in the target. Do not duplicate, edit, or replace those binaries during conversion work. Repository patches remain text-only; DerivedData, screenshots, recordings, `.xcresult`, `.xcarchive`, apps, and test bundles must not be committed.

## Controls and accessibility

* **Move up/down/left/right:** one tap of a semantic SwiftUI button produces exactly one grid-cell attempt; press and hold is a separate state that produces time-based repetition and no release step. A single primitive-button press lifecycle owns physical tap and hold dispatch, while its semantic activation triggers one move for VoiceOver. Release, cancellation, pause, dialogue, backgrounding, terminal state, and view disappearance clear held input.
* **Grapple:** fires in Lidia's current facing direction.
* **Pause:** suspends play and offers Resume or Return to Menu.
* Direction controls appear as buttons with stable identifiers (`moveUpButton`, `moveDownButton`, `moveLeftButton`, `moveRightButton`); Grapple is `grappleButton`. They expose descriptive VoiceOver labels and disabled state. Health remains readable as text even though the legacy heart is also shown. Important collection, health, chest, mine, and completion events generate one accessibility announcement per event. Reduce Motion replaces travel-heavy feedback with a fade.

## Toolchain and local validation

This repository intentionally does not run automated checks. Debug, tests, Analyze, Release, and archive validation must be performed locally with Xcode 26 before merging changes. Use a distinct DerivedData directory for the test build so the testable application module cannot be confused with an ordinary Debug build.

```bash
xcodebuild -version
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -showdestinations
rm -rf /tmp/HookshotHero-Debug-DerivedData && xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath /tmp/HookshotHero-Debug-DerivedData clean build
rm -rf /tmp/HookshotHero-Test-DerivedData && xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath /tmp/HookshotHero-Test-DerivedData clean build-for-testing
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath /tmp/HookshotHero-Test-DerivedData test-without-building
rm -rf /tmp/HookshotHero-Analyze-DerivedData && xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath /tmp/HookshotHero-Analyze-DerivedData analyze
rm -rf /tmp/HookshotHero-Release-DerivedData && xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HookshotHero-Release-DerivedData clean build
rm -rf /tmp/HookshotHero-Archive-DerivedData /tmp/HookshotHero.xcarchive && xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/HookshotHero.xcarchive -derivedDataPath /tmp/HookshotHero-Archive-DerivedData CODE_SIGNING_ALLOWED=NO archive
plutil -lint ios/HookshotHero/Resources/Info.plist ios/HookshotHero/Resources/PrivacyInfo.xcprivacy
```

Unit coverage includes a deterministic Level 1 **map-integration** command playthrough with an explicit minimal entity fixture, typed feedback, interrupted-input cancellation, terminal atomicity, shared geometry, rendering agreement, persistence, and lifecycle behavior. A separate seed-496913 production-spawn test verifies 3 mines, 2 cabbages, 10 coins, deterministic repetition, and complete-footprint exclusions. Text feedback is projected in a readable Dynamic Type SwiftUI overlay; SpriteKit retains the motion-sensitive mine burst. Input cancellation generations reset both authoritative held movement and local button presentation. Terminal contacts synchronize status before their one outcome callback; drained commands stop immediately and every later terminal-capable update phase and gameplay entry point is a no-op.

The repository intentionally has no CI workflow. The commands above are the required validation sequence on a development Mac with Xcode 26 or later; record the selected installed iPhone simulator and exact Xcode/SDK versions in the change report. They cannot be executed in a non-macOS environment that does not provide `xcodebuild` or Simulator runtimes.

## Intentionally deferred Level 1 parity

* Atmosphere music and walking, grapple, coin, healing, and explosion sounds.
* Java-parity fire and smoke emitters (the stabilization includes only basic programmatic explosion feedback).
* Optional bouncing balls.
* Mission-mode guide.

Levels 2 through 6 are registered native gameplay levels. Levels 5 and 6 each reproduce their Java maze, lava, doors, smoke emitters, Skeleton, Flying Terror, three mines, two cabbages, and ten coins. Level 5 has one side-view chest; Level 6 has independent side- and front-view chests. In DEBUG builds, the scrollable direct level selector includes Level 6.

See [Conversion decisions](Documentation/ConversionDecisions.md), [Responsibility map](Documentation/ResponsibilityMap.md), and [Temporary assets](Resources/TemporaryAssets.md).

## Shared simulation and UI publication boundary

The gameplay dependency direction is `AppRouter → GameSimulationFactory → GameSimulation → GameSession → GameplayView / GameScene`. `DefaultGameSimulationFactory` creates the concrete simulation for Levels 1 through 6; unsupported identifiers fail with `GameLoadingError.unsupportedLevel`.

The simulation is authoritative for health, score, entities, timing, and outcomes. Every Level 1 score source—coins, grapple-destroyed mines, the chest, and level completion—mutates the simulation player. `GameSession` has no score-award API and reads the final authoritative status for routing and immutable results.

SwiftUI observes the small, equatable `GameplayUISnapshot`: level identity, health, maximum health, score, movement/grapple availability, pause/dialogue presentation, and stable feedback events. Equivalent snapshots are not assigned. Feedback publishes when it is added or removed, not as its duration advances. Elapsed gameplay time is a nonpublished session value, and paused, dialogue, and background intervals remain excluded.

SpriteKit caches `LevelPresentationDefinition` once and pulls one level-neutral `GameRenderSnapshot` per active frame. The dynamic snapshot contains stable-ID render entities, grapple state, and generic effects; level geometry and one-off chest flags do not cross that boundary. Player animation time, interpolation, frame timestamps, and accumulators remain nonobservable. Unit observation tests verify that idle frames and safe empty-cell movement produce zero `GameSession.objectWillChange` events in production mode.

UI tests inject the deterministic Level 1 seed `496913` in their shared setup. A DEBUG-only coordinate diagnostic is enabled only for seeded test composition; Release gameplay does not publish coordinates.

This repository intentionally has no CI workflows or required automated checks. The complete local Xcode 26-or-later build, unit test, UI test, analyze, Release build, unsigned archive, and plist validation sequence is mandatory before release.

## Multi-level loading and render boundary

The current main menu calls `AppRouter.startNewGame()`, whose typed `GameStartConfiguration` resolves `.levelOne`. Level-specific callers use `AppRouter.startGame(levelID:)`; that API forwards the identifier, configuration, and optional deterministic seed without substituting Level 1. Construction follows `MainMenu or level selection → AppRouter.startGame(levelID:) → GameSimulationFactory → concrete GameSimulation → GameSession → GameplayView → generic GameScene`. `GameSession` accepts only a preconstructed simulation and performs no fallible factory work.

Factory errors are mapped to a stable `GameLoadingFailurePresentation`, logged with the public level identifier, diagnostic category, description, and retry status, and displayed in a recovery screen. Retry is request-identity checked and requests the exact failed level again; Return to Menu clears both the route and request. Unsupported identifiers never fall back to Level 1 and failed construction retains no session.

Gameplay now has three distinct channels:

* **Simulation state** owns authoritative rules, collisions, entities, score, health, and outcomes.
* **UI snapshot** owns health, score, dialogue, feedback, control availability, and pause presentation.
* **Render state** is an immutable, cached `LevelPresentationDefinition` plus one generic dynamic `GameRenderSnapshot` captured per active SpriteKit frame.

Level One builds floor, lava, walls, and doors as static descriptors. Its player, chest (open or closed), coins, cabbages, mines, grapple, and future effects cross the shared boundary as stable-ID generic descriptors with extensible `RenderAssetID` and animation identifiers. `TextureCatalog` caches full textures and sheet slices, preserves nearest-neighbor filtering, and reports typed missing/invalid resources. `GameScene` caches grid/layout data, never reads static geometry from a dynamic snapshot, and passes the frame's single captured snapshot through synchronization helpers. Direction buttons use SwiftUI's semantic `.disabled` state as well as cancelling physical hold state, so VoiceOver and Switch Control receive the same availability as gameplay.

Levels 3 through 6 use footprint-safe named entry anchors, construction-time initial-footprint validation, complete level-scoped asset manifests, and forward and reverse runtime transitions. Levels 2, 3, and 5 share enemy patrol, seek, contact-damage, grapple-combat, health-rendering, and defeat behavior. Forward transitions persist the completed source level, while reverse transitions do not create completion records.

## Runtime loading and renderer correction pass

This correction pass fixes the PR #14 native iOS regressions before Level 2 work begins. Logical gameplay and Codable values continue to use `Double`, while SpriteKit and Core Graphics presentation APIs receive explicit `CGFloat` conversions at the renderer boundary for node positions, sprite sizes, z positions, alpha values, anchors, and action parameters. Test simulations with side effects in computed `renderSnapshot` properties now use explicit `return` statements so render-request counting remains type-correct.

Dynamic renderer cleanup is restored to a two-phase process: active identifiers are collected, stale identifiers are filtered into a separate array, and nodes are removed from their parents before dictionary entries are removed. The generic scene applies that rule to entity and effect node dictionaries so coin, cabbage, mine, chest, and future entity disappearance remains deterministic and idempotent.

Effects are now part of the generic render snapshot flow. Level 1 mine destruction emits a stable generic `RenderEffectSnapshot` alongside the mine-specific score feedback; `GameScene` consumes `snapshot.effects` without Level 1 gameplay branches. Standard motion uses a brief scale-and-fade burst, while Reduced Motion uses the same finite lifetime with no scale animation.

Gameplay feedback uses an explicit VoiceOver announcement service. `GameplayFeedbackKind` owns event-specific wording for coins, chests, health restoration, full-health pickups, damage, mine destruction, and level completion. `FeedbackAnnouncementCoordinator` tracks feedback IDs so newly visible feedback is announced once, stable feedback is not reannounced on redraw, and view reconstruction can avoid stale duplicate announcements when the coordinator is preserved by SwiftUI state.

Level startup now goes through a `GameLevelRuntimeFactory` boundary: `AppRouter.startGame(levelID:)` asks the runtime factory to construct the simulation, static presentation, level-specific texture catalog, level-specific animation catalog, asset manifest, and asset preflight before a `GameSession` is published or gameplay navigation is pushed. Missing textures, missing animations, empty animations, and invalid texture regions are converted to typed `GameLoadingError` diagnostics and routed to the existing loading-failure recovery screen. Retry rebuilds and revalidates the complete runtime; Return to Menu clears the failure route.

Final dependency flow:

```text
Main Menu
→ AppRouter.startGame(levelID:)
→ GameLevelRuntimeFactory
    → GameSimulationFactory
    → Level presentation builder
    → Texture catalog factory
    → Animation catalog factory
    → Asset preflight
→ validated GameLevelRuntime
→ GameSession
→ GameplayView
→ generic GameScene
```

Failure flow:

```text
runtime construction or preflight failure
→ typed GameLoadingError
→ router logging
→ loading-failure route
→ Retry or Return to Menu
```

Render flow:

```text
simulation update
→ one GameRenderSnapshot
→ generic entity/effect synchronization
→ safe two-phase cleanup
```

Session observation now starts only after runtime construction, preflight, session initialization, and session start succeed. Failure handling cancels any observation even when no active session exists, clears ownership, and prevents stale callbacks from failed sessions from mutating navigation.

Local validation remains intentionally Xcode-based. Run the full Xcode 26 sequence locally: `xcodebuild -version`, `-showdestinations`, Debug build, build-for-testing, test-without-building for both `HookshotHeroTests` and `HookshotHeroUITests`, analyze, Release simulator build, unsigned device archive, `plutil -lint` for both property lists, `git diff --check`, `git status --short`, and manual review of `git grep -n "for .* in .*\\.keys"`, `git grep -n "try!"`, and `git grep -n "try?"`. The repository intentionally contains no CI workflows. The populated app icon catalog is included in runtime and archive validation.

## Level 2 Runtime Conversion

Levels 1 through 6 are implemented in the shared runtime path. A normal production playthrough starts at Level 1, and each connected exit emits a transition request that installs the destination in the same `GameSession`, preserving health, score, character identity, completion state, and elapsed playthrough time. Reverse doors use named destination entrances, including Level 5's return to Level 4's right-side door. Level 4 restores its defeated boss and open exits from carryover completion state. Levels 5 and 6 are parallel playable-content boundaries while Java Levels 7 and 8 remain deferred.

Conversion flow:

```text
LevelOneRuntime
→ transition request
→ validated LevelTwoRuntime
→ same GameSession
→ LevelTwoSimulation
```

Level 2 uses the Java 60×60 grid with 4×4 environment tiles. Internal wall anchors are row 16 columns 4, 8, 12, 16, 20, 24, 28, 32, 36, and 40; row 24 columns 8 and 12; and rows 20 and 24 at columns 36 and 40. Lava anchors are rows 32, 36, and 40 at columns 4 through 52 by fours; rows 44, 48, and 52 at columns 36, 40, 44, 48, and 52; and rows 20, 24, and 28 at columns 20, 24, and 28.

Level 2 item requirements are three mines, two cabbages, and ten coins. The deterministic Level 2 test seed is `496913`. In DEBUG UI testing, `HOOKSHOT_START_LEVEL=level-2` starts a fresh Level 2 session with health 3, score 0, and the bottom entry; `HOOKSHOT_LEVEL_SEED` controls deterministic spawning.

Level 2 contains one Skeleton and one Flying Terror. The Skeleton has 3 health, sight range 19 cells, 0.7 second patrol timing, and 0.5 second seek timing. It respects walls, may cross lava, and uses deterministic greedy fallback movement when the Java single shortest move would be blocked. The Flying Terror has 5 health, sight range 39 cells, 0.3 second patrol and seek timing, flies over walls and lava, and enforces its complete 8×8 footprint inside the board. Enemy contact damage uses the shared cooldown instead of frame-repeated damage. Grapple hits damage the first enemy footprint crossed and add 10 score per hit; no separate defeat bonus is added.

Level 2 asset requirements reference the existing tracked Java resources: `skeleton.png`, `flying_terror.png`, `smoke1.png`, `smoke2.png`, and `smoke3.png`, plus the shared Level 1 environment, Lidia, coin, mine, cabbage, and heart art. No new binary assets are required.

Intentional Java corrections:

- Overlapping enemy spawn positions were replaced with deterministic Skeleton row 5 column 23 and Flying Terror row 5 column 33 positions.
- Enemy bounds are enforced for the complete collision footprint.
- Seek movement uses greedy fallback around blocked cells rather than stalling on one blocked shortest choice.
- Random streams are injected and deterministic for item spawning, Skeleton AI, and Flying Terror AI.
- Contact damage uses the shared cooldown instead of frame repetition.
- Completion rewards cannot be farmed repeatedly during one session.

Local validation in this container is limited because `xcodebuild` and `xcrun` are not installed. The repository intentionally contains no CI workflows.

## iOS visual theme

SwiftUI interface surfaces use one centralized theme in `ios/HookshotHero/DesignSystem/AppTheme.swift`. The theme is limited to the app shell, controls, HUD, overlays, menus, settings, help, loading failure, and results UI; SpriteKit gameplay artwork, texture catalogs, animations, sprite sheets, particles, app icons, launch artwork, audio, and Java-derived image palettes are intentionally not recolored.

Theme color values are exact:

* `background`: black (`red 0`, `green 0`, `blue 0`) for screen roots, navigation backgrounds, full-screen overlays, and the SpriteKit board surround.
* `surface`: `red 0.12`, `green 0.04`, `blue 0.2` for cards, HUD containers, dialogue panels, settings/help sections, controls at rest, and error/result containers.
* `accent`: `red 0.72`, `green 0.29`, `blue 0.95` for primary actions, direction-control borders and pressed states, selected settings controls, navigation tint, and positive feedback.
* `highlight`: `red 0.98`, `green 0.32`, `blue 0.67` for Grapple, victory/game-over emphasis, chest rewards, damage, mine destruction, completion, and high-priority actions.
* `text`: white (`red 1`, `green 1`, `blue 1`) for readable labels and primary copy. Secondary copy uses reduced opacity from this semantic text color.

Typography is exposed through `AppTextStyle` with exact base sizes: `h1 = 16`, `h2 = 14`, `h3 = 12`, and `paragraph = 10`. Weights are semantic (`h1` bold, `h2` semibold, `h3` medium, `paragraph` regular) and use the rounded system design. No custom binary font file is included. Views should use `.appTextStyle(_:)` instead of arbitrary local font sizes; remaining custom system sizes are limited to SF Symbol icon presentation and fixed gameplay artwork dimensions such as the existing HUD heart image.

Reusable styling helpers are defined beside the theme: `.appTextStyle(_:)`, `.appScreenBackground()`, `.appSurface(cornerRadius:)`, `.appNavigationStyle()`, `AppPrimaryButtonStyle`, `AppSecondaryButtonStyle`, and `AppHighlightButtonStyle`. Button styles preserve semantic SwiftUI `Button` behavior, a minimum 44-point hit target, visible pressed states, and visible disabled states. Dynamic Type is supported by using SwiftUI fonts at the required base sizes with flexible stacks, wrapping, scrolling settings/help content, and full-width actions so primary controls remain visible instead of clipping.


## Levels 5 and 6 Java parity and deliberate corrections

Level 5 retains 52 internal wall anchors and 61 lava anchors. Its visible left doorway (rows 8–11, columns 0–3) returns to Level 4's right entry, intentionally correcting Java's contradictory `GetEntryGrid`. Its chest interacts at row 52, column 4 but renders with `ChestSide` at row 52, column 8. Footprint-safe player starts remain row 8, column 7 and row 5, column 29 rather than placing Lidia partly in walls. Its emitters remain at rows/columns 55/16 and 26/43.

Level 6 contains 54 internal wall anchors and 49 lava anchors. The bottom doorway (rows 56–59, columns 27–32) returns to Level 4's top entry; the upper-right exit (rows 0–3, columns 51–56) completes current content for the future Level 8 route. The bottom player entry remains at row 50, column 27. Java used `(5,23)` for the top entry, but that position is not aligned with Native Level 6's upper-right top exit/doorway. The native conversion intentionally corrects the top entry to row 5, column 53 (`(5,53)`), ensuring that a future Level 8 → Level 6 return places Lidia beneath the correct doorway with a valid collision footprint. This is an intentional Java correction and must not be reverted when Level 8 is implemented. Chests at 4/24 (`ChestSide`) and 44/8 (`ChestFront`) independently award 100 score and up to two health. Emitters are at 13/21 and 39/53. Java's overlapping enemy-at-exit defect is corrected with deterministic, footprint-safe Skeleton 22/53 and Flying Terror 10/52 starts.

Native corrections shared by both levels include full-footprint deterministic item spawning, independent random streams for items and each enemy, bounded enemy movement, stable entity identity, two-phase render cleanup, a maximum health of five, time-based damage cooldowns, and deduplicated completion rewards. Audio remains deferred. Xcode validation must be performed on macOS; this repository's Linux editing environment does not provide `xcodebuild` or Simulator runtimes.
