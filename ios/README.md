# Hookshot Hero for iOS (V2 foundation)

`ios/` contains the incremental native successor to the offline Java/Swing V1 in `Java/`. V1 remains the behavioral/content reference and must not be deleted before verified parity. This foundation does not migrate full gameplay or assets and must not receive network-based dialogue or generative-service code.

## Requirements and opening

* Xcode 16.x (project format and Swift toolchain), iOS 18 SDK
* Minimum target: iOS 18.0; iPhone portrait is the deliberate initial device family

Open `ios/HookshotHero.xcodeproj` and select the shared **HookshotHero** scheme. On a Mac, discover destinations with:

```bash
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -showdestinations
```

Then substitute an installed simulator identifier:

```bash
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' build
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Release \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' test
```

## Implemented

Typed SwiftUI routing launches at an accessible main menu and creates one disposable session. A development-only SpriteKit scene demonstrates delta-time movement, pause/resume, lifecycle pause, and cleanup. Injected settings and versioned atomic progression persistence have unit coverage, alongside safe entity mutation and timing. XCUITests cover the essential menu/gameplay/settings flows.

## Limitations

The player circle, system symbols, colors, and empty app-icon slot are placeholders. There are no final controls, physics, levels, missions, migrated saves, audio, iPad layout, controller support, or Java assets. Foregrounding intentionally requires explicit resume. Command-line Xcode validation requires macOS and is unavailable in Linux environments.

## Documentation

* [Java-to-Swift inventory](Documentation/JavaToSwiftInventory.md)
* [Responsibility map](Documentation/ResponsibilityMap.md)
* [Conversion decisions](Documentation/ConversionDecisions.md)
* [Temporary asset register](Resources/TemporaryAssets.md)
