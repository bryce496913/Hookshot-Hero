# Responsibility map

This map follows call sites and state in the Java sources rather than names alone.

| Java system | Current responsibility | Known problem | Swift replacement | Phase |
|---|---|---|---|---|
| `StartMenu` | Creates mode options, engine, Swing menu, theme, help | Desktop UI; engine constructed before play | `MainMenuView`, `AppRouter` | Foundation |
| `GameEngine` | Swing frame/panel, global keyboard dispatcher, Timer update/repaint | UI/simulation coupled; swallowed sleep error; listener lifetime risk | SwiftUI lifecycle + router-owned `GameSession` + scene-local `GameScene` resources | Foundation |
| `HookshotHeroesGameEngine` | World creation, pause, render/update, level replacement | Lazy world initialization in paint; fixed desktop dimensions | `GameSession`, scene, later world simulation | Core gameplay |
| `World` | Entities, collision, render, spawn/elimination/audio/animation queues | Collision split with objects; only one queued spawn/removal consumed per update | Simulation world + `EntityStore` | Core gameplay |
| `Player` / `NPCPlayer` / `BGCPlayer` | Player stats, grid movement, grapple and NPC variants | Rendering, input, collision and state are coupled | Component entities + player controller | Gameplay |
| `IWorldObject` implementations | Items, bosses, enemies, particles, notifications | Framework drawing embedded in domain objects | SpriteKit render adapters + models | Gameplay |
| `LevelOne`…`LevelTen`, `BaseLevel` | Terrain cells, exits, rendering and level links | Content and rendering coupled; static cross-level flags exist | Codable level definition + renderer | Levels |
| State-machine classes | Patrol/seek/follow/wait decisions | Euclidean chase ignores blocked paths; mutable timing in entities | Deterministic behavior systems | NPC slice |
| `KeyBinding`, `World.HandleKeyEvents` | Two-player keyboard commands | Unsuitable for touch/accessibility | Touch input controller | Gameplay |
| `GameImage` | Eager classpath sprite loading | Desktop images unaudited for iOS | Asset catalog/texture loader | Assets |
| `GameAudio` / audio requests | Eager WAV loading, queues and playback | Audio lifecycle tied to engine | AVAudioEngine service (design pending) | Audio |
| `GameOptions` | Mutable mode/music/volume/display options | No durable preference repository identified | resilient `GameSettings` + immutable per-session configuration | Foundation |
| `StopWatch` | Wall-clock elapsed display | Separate pause state can diverge from engine | authoritative session delta time | Foundation |
| `SpeechService` | Local predefined event dialogue | Randomness is not injectable | local dialogue content service | Later content |
| Builders and interfaces | Assemble mode-specific world and dependencies | Large object graph and desktop dependencies | Explicit factories/configuration | Core gameplay |

No save-data class or mission-definition class separate from `GameOptions.MissionMode` and quest/world-builder behavior was found. Those areas require investigation rather than an invented one-to-one mapping.
