# Foundation conversion decisions

* **UI and navigation:** SwiftUI owns typed navigation. SpriteKit nodes never navigate. Terminal session transitions are observed and handled centrally by `AppRouter`, which replaces gameplay with an immutable results route.
* **Session ownership:** `AppRouter` is the exclusive creator and disposer of `GameSession`. Views request actions but do not dispose sessions. Scenes release only scene-local resources and never dispose sessions. Session identity guards reject stale lifecycle and outcome callbacks.
* **Application lifecycle:** Inactivity prevents loading/initialized sessions from running and pauses running sessions with a typed application-lifecycle reason. Activation never silently resumes; explicit player resume is required. Terminal/disposed sessions ignore later lifecycle events.
* **Scene lifecycle:** Presentation installation, domain initialization, session start policy, local observation, and timing reset are separate idempotent operations. Reattachment neither duplicates the marker nor initializes the world twice.
* **Timing:** The clock is reset at attach, detach, pause, resume, background, and terminal boundaries. Thus the first resumed frame is zero while ordinary running gaps remain clamped to 1/15 second.
* **Entities:** Deferred mutation remains safe before and after iteration. Removal wins over addition at the same safe point. The first active or pending UUID wins and later duplicate additions are logged and ignored, preserving stable accepted-addition order.
* **Persistence:** Progression is a separate atomic document owned at runtime by `ProgressionStore`. Schema versions are inspected before full decoding; V0 migrates sequentially to V1, future versions are rejected, and corrupt/unsupported originals are never automatically overwritten.
* **Settings:** A new session snapshots only implemented settings. App-specific Reduce Motion OR system Reduce Motion stops normal placeholder movement. The control-hint preference controls the current pause hint. Deferred audio and haptic switches are hidden.
* **Placeholders:** System symbols, catalog colors, the empty icon slot, and cyan circle remain development-only. No Java gameplay, generative/network dialogue, or unaudited asset library is copied.

Follow-up decisions remain for touch controls, orientation/iPad policy, controller support, Java-save migration, licensed asset migration, audio design, and level scaling. A final approved app icon and distribution signing are release blockers.

## Level 1 gameplay corrections

The native Level 1 simulation deliberately uses elapsed-time movement and hookshot steps rather than rendered frames. Lava contact removes exactly one health point, restores Lidia's last safe cell, and applies a 0.75-second cooldown; a latched hook pull is immune to lava. This corrects the Java update-loop behavior that could repeatedly damage the player at different display refresh rates. Spawning enumerates safe cells before shuffling, so it cannot retry forever, and all collection/removal uses stable UUIDs. `AppRouter` now constructs, validates, initializes, and starts the world before navigation; SpriteKit only presents that existing simulation.

## Level 1 stabilization

* `LevelBoundaryGeometry` is the single authority for boundary collision and SpriteKit wall/door layout; the top opening remains six cells wide (columns 27 through 32) and the lower door remains blocked.
* Center-anchored, device-independent collision footprints define player, item, chest, exit, and grapple contact. Deterministic spawning rejects complete footprints that touch blocked, hazardous, protected, or occupied regions.
* Typed gameplay feedback is rendered, expires by simulation elapsed time, respects Reduce Motion, and produces event-level accessibility announcements. Mine destruction uses a programmatic burst and the existing heart resource supports the textual health HUD.
* Chest dialogue is a `GameSessionState` interruption. It cancels input and freezes simulation/time; lifecycle inactivity preserves the dialogue and Continue resumes only while active.
* Direction-pad elements are semantic SwiftUI buttons with accessible tap activation plus owned press/release state for time-based repetition.
* Scene dictionaries use a two-phase stale-ID calculation before removal, including entity and feedback nodes, so synchronization is idempotent and never mutates an active iteration.
* Deterministic geometry, footprint, spawn, feedback, dialogue, movement, grapple, scoring, and victory tests protect shared Level 1 systems before Level 2 work begins.

## Level 1 stabilization

Gameplay feedback uses event-specific associated-value cases. SwiftUI presents readable, stacked screen-space text while SpriteKit owns only world effects; chest score and health are one event and one announcement. Direction controls observe the authoritative input controller's cancellation generation, so dialogue, pause, lifecycle suspension, terminal state, and disappearance clear local press presentation as well as held simulation input. Entity-array order is the deterministic same-frame interaction order. A lethal contact synchronizes health and score, marks the world terminal, emits one outcome, and stops later contacts. Seed `496913` supplies the documented full-map regression fixture (coin at row 42/column 27 and mine at row 53/column 27), exercised from the production start with normal commands.

## Multi-level dependency boundary

Gameplay construction now follows `AppRouter → GameSimulationFactory → GameSimulation → GameSession → GameplayView and GameScene`. SwiftUI consumes only equatable UI snapshots, while SpriteKit pulls nonobservable render snapshots. The concrete simulation remains authoritative, including every score mutation; level-specific rules stay in `LevelOneSimulation`. The factory has an explicit typed unsupported-level error and is the future extension point for Level 2, which is intentionally not part of this pass.

## Multi-level dependency direction

The validated dependency target is `MainMenu or level selection → AppRouter.startGame(levelID:) → GameSimulationFactory → concrete GameSimulation → GameSession → GameplayView → generic GameScene`. Fallible construction ends at the factory. Simulation state, the equatable SwiftUI snapshot, and static-plus-dynamic render state are deliberately independent. A level supplies an immutable presentation definition and generic dynamic descriptors; the shared scene contains no level gameplay switches. Level 2 is to enter through new simulation, definition, presentation, asset mappings, and factory support only.
