# Hookshot Hero for iOS — playable Level 1

The native SwiftUI/SpriteKit conversion now provides a complete, playable **Level 1 vertical slice** while the Java game remains the behavioral reference. Level 2 is explicitly deferred.

## Current gameplay

Lidia starts on the original 60×60 board at row 50, column 27. Native direction-pad controls support tap and hold movement, and Grapple fires in her facing direction with the original 19-cell range. Walls, the six-cell top exit, the closed lower door, lava damage and safe-position restoration all participate in collision. Coins, cabbages, mines, and the talking chest are interactive. Victory, defeat, automatic results navigation, high scores, and Level 1 completion persistence are implemented.

Shared boundary geometry drives simulation and SpriteKit presentation. Device-independent collision footprints cover Lidia and every item; deterministic spawning validates the entire footprint against walls, lava, doors, the chest, start safety region, and other entities. Typed, elapsed-time feedback presents score and health changes, uses the bundled `heart.png` in the HUD, announces important events through VoiceOver, and supplies a programmatic mine explosion. Chest dialogue suspends simulation and elapsed time until Continue.

The existing Java sprite resources are bundled directly in the target. Do not duplicate, edit, or replace those binaries during conversion work. Repository patches remain text-only; DerivedData, screenshots, recordings, `.xcresult`, `.xcarchive`, apps, and test bundles must not be committed.

## Controls and accessibility

* **Move up/down/left/right:** tap a semantic SwiftUI button for one command; press and hold for time-based repetition. Release, cancellation, pause, dialogue, backgrounding, terminal state, and view disappearance clear held input.
* **Grapple:** fires in Lidia's current facing direction.
* **Pause:** suspends play and offers Resume or Return to Menu.
* Direction controls appear as buttons with stable identifiers (`moveUpButton`, `moveDownButton`, `moveLeftButton`, `moveRightButton`); Grapple is `grappleButton`. They expose descriptive VoiceOver labels and disabled state. Health remains readable as text even though the legacy heart is also shown. Important collection, health, chest, mine, and completion events generate one accessibility announcement per event. Reduce Motion replaces travel-heavy feedback with a fade.

## Toolchain and validation

Use a stable **Xcode 26 or later** with an **iOS 26 SDK or later**. The minimum deployment target is **iOS 18.0**. Strict Swift concurrency checking is enabled. Open `ios/HookshotHero.xcodeproj` and use the shared `HookshotHero` scheme.

```bash
xcodebuild -version
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -showdestinations
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath /tmp/HookshotHero-LevelOne-Stabilization clean build
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath /tmp/HookshotHero-LevelOne-Stabilization test
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath /tmp/HookshotHero-LevelOne-Stabilization analyze
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HookshotHero-LevelOne-Stabilization-Release clean build
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/HookshotHero-LevelOne-Stabilization.xcarchive -derivedDataPath /tmp/HookshotHero-LevelOne-Stabilization-Archive CODE_SIGNING_ALLOWED=NO archive
plutil -lint ios/HookshotHero/Resources/Info.plist ios/HookshotHero/Resources/PrivacyInfo.xcprivacy
```

The `.github/workflows/ios-ci.yml` workflow exposes the stable **ios-validation** job on relevant pull requests and pushes to `main`. It selects stable Xcode 26, discovers an available iPhone simulator, and runs plist validation, Debug build, unit and UI tests, Analyze, Release simulator build, and an unsigned device archive with pipeline exit-code preservation and failed-log upload. To make it a merge requirement, a repository administrator must open **Settings → Branches or Rulesets** and require `ios-validation` before merging to `main`.

Unit coverage protects shared geometry, render/collision agreement, collision footprints and spawn safety, time-based movement/grapple behavior, feedback lifetime, dialogue lifecycle, node synchronization, scoring, and deterministic spawn behavior. UI coverage queries semantic controls as buttons and covers play/pause/results flows.

## Intentionally deferred Level 1 parity

* Atmosphere music and walking, grapple, coin, healing, and explosion sounds.
* Java-parity fire and smoke emitters (the stabilization includes only basic programmatic explosion feedback).
* Optional bouncing balls.
* Mission-mode guide.
* Transition into Level 2.
* Approved final app icon (the empty catalog slot remains a distribution blocker).

No Level 2 enemies, missions, or transition are part of this stabilization pass.

See [Conversion decisions](Documentation/ConversionDecisions.md), [Responsibility map](Documentation/ResponsibilityMap.md), and [Temporary assets](Resources/TemporaryAssets.md).
