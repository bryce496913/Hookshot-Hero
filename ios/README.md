# Hookshot Hero for iOS — playable Level 1

The native SwiftUI/SpriteKit conversion now provides a complete, playable **Level 1 vertical slice** while the Java game remains the behavioral reference. Level 2 is explicitly deferred.

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
* Transition into Level 2.
* Approved final app icon (the empty catalog slot remains a distribution blocker).

No Level 2 enemies, missions, or transition are part of this stabilization pass.

See [Conversion decisions](Documentation/ConversionDecisions.md), [Responsibility map](Documentation/ResponsibilityMap.md), and [Temporary assets](Resources/TemporaryAssets.md).

## Shared simulation and UI publication boundary

The gameplay dependency direction is `AppRouter → GameSimulationFactory → GameSimulation → GameSession → GameplayView / GameScene`. `DefaultGameSimulationFactory` currently creates only `LevelOneSimulation`; unsupported identifiers fail with `GameLoadingError.unsupportedLevel`. Level 2 is not implemented.

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

A future Level 2 should add `LevelTwoSimulation`, `LevelTwoDefinition`, `LevelTwoPresentationDefinition`, Level Two catalog mappings, and explicit factory support. It must not add Level Two gameplay branches to the generic scene or rewrite Level One. This boundary remains pending complete Xcode 26 validation before Level 2 work begins.
