/**
 * Resets process-global gameplay state for a fresh debug session.
 */
public final class DebugGameState {
    private DebugGameState() {
    }

    public static void ResetDebugGameState() {
        Minotaur.BossIsDead = false;
        LevelSeven.FromLevelSeven = false;
    }
}
