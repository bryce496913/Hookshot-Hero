# Hookshot Hero

This repository contains two deliberately separate generations of Hookshot Hero:

* `Java/` is the sanitized, offline Java/Swing V1 and remains the behavioral and content reference.
* `ios/` is the native SwiftUI and SpriteKit V2 foundation under active incremental conversion.

The Java project must remain in the repository until gameplay and content parity have been verified. The iOS project contains no network-based dialogue or generative-service integration, and none should be introduced during conversion.

See [`ios/README.md`](ios/README.md) for native build, test, architecture, and migration documentation.

## Licensing and bundled assets

Hookshot Hero source code is offered under the repository's MIT license. That license does **not** cover or relicense third-party artwork, audio, or other media retained in this repository or bundled with the iOS app. See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for the authoritative native-target asset inventory, applicable notices, and release-blocking provenance issues. The historical credits in `Java/README.md` remain unchanged and are attribution evidence rather than distribution clearance.
