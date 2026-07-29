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
