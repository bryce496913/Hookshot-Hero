# V1 readiness fixes and remaining validation

## Implemented corrections

- Level 4 has a wall-free, grappleable backward doorway. A movement-driven regression approaches it with the complete player footprint centered in the opening.
- Door regressions advance through realistic bounded updates; Country Road approaches the castle from inside the board.
- The construction matrix includes all supported entries through Hero's Welcome.
- Debug defines the Swift DEBUG compilation condition; Release does not enable the test harness.
- Palace NPC and furnishing crops use actual PNG dimensions. Texture loading rejects mismatched sheet dimensions and invalid crop sizes.
- Backgrounding during a transition retains the requirement for explicit Resume, regardless of foreground/scene-attachment order.
- Levels 1–3 exclude their actual player arrival footprint from random item placement.
- Level 10 and Country Road preflight their dynamic collectibles and animations.
- The gameplay representable retains its SKView identity across scene replacements.
- Support availability copy follows the configured support URL.

Focused regressions were added in the existing test targets for physical reverse routing, multi-seed arrival exclusion, lifecycle ordering, crop dimensions, invalid sheet metadata, all registered textures, and dynamic manifest coverage.

## Validation performed in the Linux workspace

Read-only checks confirmed plist/asset JSON parsing, source membership, the 48-entry resource inventory, 37 literal sheet crops against PNG dimensions and bounds, animated/shared sheet dimensions, the physical Level 4 reverse approach, Debug-only compilation conditions, corrected door fixtures, and absence of binary changes. `git diff --check` passed.

These checks do not execute Swift, UIKit, SpriteKit, XCTest, Xcode Analyze, or an archive. No Xcode build or test result is claimed.

## Required Apple validation

On macOS, record Xcode and installed SDK/simulator versions. Choose an installed iPhone Simulator UDID. Keep all generated output outside the repository.

```sh
validation_root="$(mktemp -d /tmp/HookshotHero-V1.XXXXXX)"
simulator_udid="REPLACE_WITH_INSTALLED_IPHONE_SIMULATOR_UDID"
xcodebuild -version
xcode-select -p
xcodebuild -showsdks
xcrun simctl list devices available
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination "id=$simulator_udid" -derivedDataPath "$validation_root/DerivedData" clean build
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination "id=$simulator_udid" -derivedDataPath "$validation_root/DerivedData" build-for-testing
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination "id=$simulator_udid" -derivedDataPath "$validation_root/DerivedData" -only-testing:HookshotHeroTests -resultBundlePath "$validation_root/Unit.xcresult" test-without-building
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination "id=$simulator_udid" -derivedDataPath "$validation_root/DerivedData" -only-testing:HookshotHeroUITests -resultBundlePath "$validation_root/UI.xcresult" test-without-building
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Debug -destination "id=$simulator_udid" -derivedDataPath "$validation_root/DerivedData" analyze
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath "$validation_root/ReleaseDerivedData" build
xcodebuild -project ios/HookshotHero.xcodeproj -scheme HookshotHero -configuration Release -destination 'generic/platform=iOS' -derivedDataPath "$validation_root/ArchiveDerivedData" -archivePath "$validation_root/HookshotHero.xcarchive" CODE_SIGNING_ALLOWED=NO archive
```

Record exact executed/passed/failed/skipped test counts. An unsigned archive does not establish signing, export, upload, or App Store readiness. Verify both forward campaign branches, dungeon reverse navigation, boss/chest persistence, lava and two-thumb controls, scene replacement, background/foreground around transitions, menu return, and save relaunch on Simulator/device.

## Distribution and submission remain blocked

Both documented Google Sites destinations were attempted again, but the configured proxy was unreachable. Anonymous HTTPS content verification was not possible, so `LegalSupportLinks` remains unset. A network-enabled operator must verify the exact privacy and support pages and reviewed wording before configuring them and entering metadata in App Store Connect. See `AppStoreSubmissionChecklist.md`.

No ownership or license terms were invented. All unresolved artwork categories remain blocked as recorded in `THIRD_PARTY_NOTICES.md` and `AssetLicenseAudit.md`. Owner evidence is still needed for the app icon and other undocumented artwork, and an explicit, verified distribution-license selection is needed for Lidia. The existing project-code MIT notice remains bundled. No binary files were changed.
