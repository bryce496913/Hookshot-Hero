# Java-to-Swift inventory

## Sanitization and dependency audit

The tracked tree contains no connector class, network client libraries, credential files, or network dialogue calls. `SpeechService` is local and the Java sources compile without third-party libraries. Sanitization commit `cace4c9` removed the connector and HTTP/JSON/Kotlin jars; credential revocation/rotation is an external repository-owner action and is not represented as source code. Nothing from that removed system is eligible for migration.

The application has no declared third-party runtime dependency after sanitization: Swing/AWT, ImageIO, Java Sound, collections and concurrency utilities are JDK APIs. Resources load through classpath paths such as `MainImage.png`, `environment/floor.png`, `npc/a1.png`, and WAV names in `Java/resources/`.

## Important classes

| File | Current responsibility / dependencies | Defects, risks, or ambiguity | Proposed Swift replacement | Status |
|---|---|---|---|---|
| `Java/src/HeroWelcome.java` | `main`; schedules `StartMenu.show` on Swing EDT | No app lifecycle model | `HookshotHeroApp` | Replace with Apple framework |
| `Java/src/StartMenu.java` | mode menu/help/theme; `GameOptions`, engine, Java Sound | async help creates Swing UI off EDT; desktop-only | `MainMenuView`, router, help view | Rewrite |
| `Java/src/GameEngine.java` | JFrame/JPanel, Swing Timer delta loop, rendering helpers, input dispatcher, audio | broad god-class; exception swallowed; dispatcher disposal needs audit | SwiftUI + SpriteKit + focused services | Split |
| `Java/src/HookshotHeroesGameEngine.java` | builds world; pause/update/render/level transitions | initializes world during paint; nullable resource failures; 600×650 assumptions | session + scene + simulation factory | Split |
| `Java/src/World.java` | object list, input/collision, requests, levels/results | collision occurs here and in objects; static boss/level flags reset; one request processed/cycle | simulation world + safe entity store | Rewrite |
| `Java/src/IWorld.java`, `IWorldObject.java` | broad world/entity contracts | objects own drawing, input and game rules | smaller protocols/components | Split |
| `Java/src/BaseWorldBuilder.java`, `SinglePlayerWorldBuilder.java`, `DoublePlayerWorldBuilder.java`, `IWorldBuilder.java` | construct mode-specific worlds/entities | exact mode parity and quest injection need characterization | session/world factory | Combine |
| `Java/src/Player.java` | stats, movement, grapple, collisions, rendering, reactions | many responsibilities; grid movement; mutable public score/lives | player model + movement/grapple/render components | Split |
| `Java/src/NPCPlayer.java`, `BGCPlayer.java`, `Guide.java` | follower/background/guide variants | behavior and presentation coupled | entity components + behavior system | Rewrite |
| `Java/src/Minotaur.java`, `GhostWizard.java`, `Skeleton.java`, `FlyingTerror.java` | boss/enemy logic and rendering | static boss state and pathfinding limitations | enemy models and behavior systems | Rewrite |
| `Java/src/Apple.java`, `Broccoli.java`, `Cabbage.java`, `Coin.java`, `Chest.java`, `Mine.java`, `Ball.java` | consumables, obstacle, projectile interactions | spawn placement can be inaccessible; collision ownership duplicated | data-driven entity components | Preserve behavior |
| `Java/src/Particle.java`, `FireParticle.java`, `SmokeParticle.java` and emitters | transient particle effects | custom desktop renderer | `SKEmitterNode` configurations | Replace with Apple framework |
| `Java/src/BaseLevel.java`, `ILevel.java`, `LevelOne.java`…`LevelTen.java`, `Levels.java` | grids, exits, entry, links, rendering | rendering/content coupled; branching/scaling unclear | versioned level definitions + renderer | Split |
| `Java/src/NextLevelInfo.java`, `LevelStartPos.java`, `GridCell.java` | level graph and grid value types | coordinate/device scaling unresolved | typed Swift value models | Preserve behavior |
| `Java/src/NPCSimpleStateMachine.java`, `FollowerStateMachine.java`, `BGCSimpleStateMachine.java`, `FTStateMachine.java`, `SkeletonStateMachine.java` | patrol/seek/wait AI with reaction timers | Euclidean selection can get stuck; randomness/time not injected | deterministic behavior systems | Rewrite |
| `Java/src/IStateMachine.java`, `NPCStates.java` | state-machine contract/state enum | contract may be too entity-specific | typed Swift behavior state | Combine |
| `Java/src/KeyBinding.java`, `PlayerDirection.java` | maps desktop keys/directions | two-keyboard-player semantics do not map to iPhone | touch input abstraction | Replace with Apple framework |
| `Java/src/GameImage.java`, `ObjectImage.java`, `Skin.java`, `NPCSprites.java` | classpath images/sprite selection | dimensions, licenses and transparency need audit | asset catalog + texture manifest | Needs investigation |
| `Java/src/GameAudio.java`, `AudioRequest.java`, `AudioVoiceType.java` | WAV preload/request playback | interruption/session handling absent | AVFoundation audio service | Replace with Apple framework |
| `Java/src/AnimationRequest.java`, `NotificationType.java` | queued bubbles/notifications | sort/order and expiration need characterization | presentation-event queue | Preserve behavior |
| `Java/src/GameOptions.java`, `DefaultMenuBarBuilder.java`, `IMenuBarBuilder.java` | mode/music/volume and in-game Swing menus | mutable options combine session and preferences | settings store + SwiftUI controls | Split |
| `Java/src/StopWatch.java` | elapsed wall clock with pause | may diverge from update lifecycle | `GameSession.elapsedTime` | Remove |
| `Java/src/SpeechService.java`, `SpeechType.java` | local randomized comments | randomness prevents deterministic tests | local content service | Rewrite |
| `Java/src/Vector2D.java`, `CollisionCheckInfo.java`, `Comparators.java`, `ColorUtils.java`, `StringUtils.java`, enums | math/collision and utilities | utility necessity varies; collision behavior unresolved | CoreGraphics/SpriteKit and focused extensions | Needs investigation |

## Cross-cutting findings

* **Entry and window:** `HeroWelcome` → `StartMenu` → `HookshotHeroesGameEngine`; engine creates a fixed Swing window and menu bar.
* **Loop/threading:** Swing `Timer` calls update then repaint on the EDT. Help uses `CompletableFuture`; Swing creation there warrants review. A global keyboard dispatcher is registered and must be explicitly removed.
* **Levels/missions:** ten concrete levels form a linked/branching graph. “Mission” is a mode flag with quest NPC construction, not a standalone mission model.
* **Persistence/settings:** no progression save implementation was found. `GameOptions` is in-memory configuration; therefore V2 save migration format is unresolved.
* **Known behavior not to reproduce:** paint-triggered initialization, static cross-session boss/level flags, split collision authority, inaccessible random spawns, pathfinding through obstacles, broad mutable public state, and resource failures that terminate or return null.
