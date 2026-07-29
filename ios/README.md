# Hookshot Hero for iOS (V2 foundation)

`ios/` is the incremental native successor to the offline Java/Swing V1. The Java implementation remains an untouched behavioral reference; this foundation does not convert gameplay.

## Toolchain and validation

Development and release validation require a **stable Xcode 26 or later** and an **iOS 26 SDK or later**. The minimum deployment target remains **iOS 18.0**. Strict Swift concurrency checking is enabled. Open `ios/HookshotHero.xcodeproj` and use the committed `HookshotHero` scheme.

Discover an installed iPhone simulator, then run:

```bash
xcodebuild -version
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -showdestinations
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug \
  -destination 'platform=iOS Simulator,id=<AVAILABLE-SIMULATOR-UDID>' clean build
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug \
  -destination 'platform=iOS Simulator,id=<AVAILABLE-SIMULATOR-UDID>' test
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug \
  -destination 'platform=iOS Simulator,id=<AVAILABLE-SIMULATOR-UDID>' analyze
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Release \
  -destination 'generic/platform=iOS Simulator' clean build
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Release \
  -destination 'generic/platform=iOS' -archivePath /tmp/HookshotHero.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

The Linux cleanup environment did not contain `xcodebuild`; therefore local build, test, analysis, SDK, simulator, warning-count, and archive results remain unverified until the Xcode 26 CI job succeeds. `.github/workflows/ios-ci.yml` repeats plist lint, simulator discovery, Debug/Release builds, unit/UI tests, Analyze, and unsigned archive validation, and uploads a failed test result bundle.

## Foundation behavior

* `AppRouter` exclusively creates, observes, and disposes the one active `GameSession`. Views and SpriteKit scenes never dispose domain state. Terminal state observation snapshots an immutable result, records progression once, disposes the session, and replaces gameplay with the results route.
* Scene attachment installs presentation idempotently, initializes the world once, binds one scene-local subscription, and resets timing. Detachment cancels local work and timing only. Pause, resume, app inactivity, terminal state, detach, and reattach all invalidate the previous timestamp. Foregrounding never automatically resumes gameplay.
* Progression schema 1 loads directly. The controlled schema-0 fixture migrates sequentially to schema 1. Corrupt data and unsupported future schemas are reported and preserved rather than overwritten. `ProgressionStore` is part of app composition and records higher scores and win completion.
* Each new session receives an immutable configuration snapshot. Effective Reduce Motion is the stored app preference OR the system Reduce Motion preference. It stops placeholder marker movement. Control Hints shows or hides the implemented pause hint. Audio and haptic settings remain deferred and are not displayed as no-op controls.
* Debug UI tests launch with `--ui-testing --reset-persistent-state`, an isolated UserDefaults suite, and an isolated temporary progression document. Debug-only forced outcome arguments are `--force-game-outcome=win` and `--force-game-outcome=loss`; Release builds ignore the UI-test configuration.

## Release limitations

No approved 1024×1024 Hookshot Hero icon was found. The catalog slot deliberately remains empty and is a release/App Store blocker; no generic artwork was invented. Distribution signing is also outside this cleanup. Final controls, physics, levels, missions, enemies, audio, haptics, and Java assets remain future slices.

See [Conversion decisions](Documentation/ConversionDecisions.md), [Responsibility map](Documentation/ResponsibilityMap.md), and [Temporary assets](Resources/TemporaryAssets.md).
