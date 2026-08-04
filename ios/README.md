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

Unit coverage includes a deterministic complete Level 1 command playthrough, typed feedback, interrupted-input cancellation, terminal collision ordering, shared geometry, rendering agreement, persistence, and lifecycle behavior. Text feedback is projected in a readable Dynamic Type SwiftUI overlay; SpriteKit retains the mine burst. Input cancellation generations reset both authoritative held movement and local button presentation. Terminal contacts synchronize status before their one outcome callback and stop later same-update entity processing.

## Intentionally deferred Level 1 parity

* Atmosphere music and walking, grapple, coin, healing, and explosion sounds.
* Java-parity fire and smoke emitters (the stabilization includes only basic programmatic explosion feedback).
* Optional bouncing balls.
* Mission-mode guide.
* Transition into Level 2.
* Approved final app icon (the empty catalog slot remains a distribution blocker).

No Level 2 enemies, missions, or transition are part of this stabilization pass.

See [Conversion decisions](Documentation/ConversionDecisions.md), [Responsibility map](Documentation/ResponsibilityMap.md), and [Temporary assets](Resources/TemporaryAssets.md).
