# Foundation conversion decisions

## Decisions

* **App UI:** SwiftUI owns menus, typed navigation, settings, help, results, and lifecycle observation. SpriteKit nodes never navigate.
* **Gameplay:** SpriteKit provides the real-time render/update surface without adding a third-party engine. `GameScene` is main-actor isolated and receives its session explicitly.
* **Ownership:** `AppRouter` owns at most one `GameSession`; the session is authoritative for lifecycle and HUD state. Dismissal disposes it and the scene stops actions.
* **Timing:** SpriteKit timestamps produce delta time. `SimulationClock` rejects negative deltas and clamps gaps to 1/15 second. Movement uses units per second, not frame count.
* **Mutation:** `EntityStore` queues additions/removals and applies them before and after, never during, iteration.
* **Persistence:** small preferences use an injected repository over `UserDefaults`; progression is a separate versioned `Codable` document written atomically. Corrupt files remain untouched and yield an explicit result.
* **Placeholders:** system symbols, catalog colors, the empty icon slot, and cyan circle are registered in `Resources/TemporaryAssets.md` as development-only.
* **Deliberate omissions:** no Java Swing/AWT UI, Java timer, keyboard controls, raster/audio library, Java serialization, network dialogue, or complete gameplay implementation is copied.

Foreground activation deliberately leaves an automatically paused session paused. The player must explicitly resume.

## Unresolved decisions

Dedicated follow-up review is required for final touch controls, orientation policy, iPad layout, controller support, V1 save migration, exact licensed asset migration, audio session/engine design, and level scaling across device sizes. Grid rules, grapple collision ordering, level branching, quest behavior, and difficulty parity also need executable characterization before conversion.
