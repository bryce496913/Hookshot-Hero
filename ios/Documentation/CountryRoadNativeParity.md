# Country Road native parity

`CountryRoad.java`, `SinglePlayerWorldBuilder.java`, `BaseWorldBuilder.java`, and
`GameImage.java` are the executable references for this standalone area.

The native area preserves the Java grass/cobble ground, road, two-row water crossing,
wood bridge, cliffs, stalls, wheat, bags, island, lake, animated waterfall, castle wall,
and doorway. Java's individual `AddWallCell` coordinates are preserved. Native additionally
closes the perimeter between those sparse cells and widens the forward trigger so the player's
3x3 footprint can enter safely. The Java bottom start `(50, 27)` is safe and retained. Its
reachable top trigger now sends a typed transition request to Hero's Welcome's footprint-safe
bottom entry; the session/router owns construction, asset preflight, and runtime installation.
Level 10 is intentionally unchanged.

Java's `NextLevels` and `GetExitGrid` both place the forward castle-approach transition at the
top `(0, 27)`. The castle wall and door artwork, however, is rendered along the bottom edge at
`y = 565`, beside the retained bottom entry, in both Java and native presentations. Thus the
forward trigger and the only rendered castle door are not visually colocated in the source map.
This pass preserves that existing scenery and collision geometry rather than silently moving the
door, changing the route, or adding another exit; aligning the forward approach artwork would be
a separate geometry/presentation correction.

The tracked `country1.png`, `terrain.png`, `water.png`, and `castle1.png` sheets contain every
required environment image and are referenced directly by the app target. No environment
binary is missing.

Country Road deterministically creates exactly five cabbages and fifteen coins, protects their
complete footprints from walls, entry, doorway, exit, and one another, and creates no standard
dungeon mines or enemies.

## Shared NPC dependency

The native runtime has enemy state and mission carryover, but no general background-character
or dialogue-guide population system. Consequently this focused port records and tests the Java
population contract—9 Child, 5 Old, and 15 Townfolk—but does not render or simulate them.
Mission Mode is likewise not represented by `GameConfiguration`, so Sarah and her Java arrival
dialogue, `You made it!!!`, require a separate shared-NPC pass. That pass should introduce
reusable NPC archetypes/state/rendering, deterministic footprint-safe placement and wandering,
guide dialogue interaction, mission-mode configuration, and the existing Sarah sprite manifest;
none of those concerns belong as Country Road branches in `GameScene`.
