# Country Road native parity

`CountryRoad.java`, `SinglePlayerWorldBuilder.java`, `BaseWorldBuilder.java`, and
`GameImage.java` are the executable references for this standalone area.

The native area preserves the Java grass/cobble ground, road, two-row water crossing,
wood bridge, cliffs, stalls, wheat, bags, island, lake, animated waterfall, castle wall,
and doorway. Java's individual `AddWallCell` coordinates are preserved. Native additionally
closes the perimeter between those sparse cells and widens the castle trigger so the player's
3x3 footprint can enter safely. The Java bottom start `(50, 27)` is safe and retained. Its
top trigger is reachable and currently produces a local win; it does not construct or route to
HeroWelcome, and Level 10 is intentionally unchanged.

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
