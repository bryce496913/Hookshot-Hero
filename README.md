# Hookshot Hero

This repository contains two deliberately separate generations of Hookshot Hero:

* `Java/` is the sanitized, offline Java/Swing V1 and remains the behavioral and content reference.
* `ios/` is the native SwiftUI and SpriteKit V2 foundation under active incremental conversion.

The Java project must remain in the repository until gameplay and content parity have been verified. The iOS project contains no network-based dialogue or generative-service integration, and none should be introduced during conversion.

See [`ios/README.md`](ios/README.md) for native build, test, architecture, and migration documentation.
