import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * A level-select choice and the gameplay context in which it should begin.
 */
public final class DebugLevelLaunch {
    public enum EntryContext {
        NEW_GAME,
        LEVEL_EIGHT_FROM_LEVEL_SIX,
        LEVEL_EIGHT_FROM_LEVEL_SEVEN
    }

    private final LevelDefinition levelDefinition;
    private final String displayName;
    private final EntryContext entryContext;

    public DebugLevelLaunch(LevelDefinition levelDefinition, String displayName, EntryContext entryContext) {
        this.levelDefinition = levelDefinition;
        this.displayName = displayName;
        this.entryContext = entryContext;
    }

    public LevelDefinition GetLevelDefinition() {
        return levelDefinition;
    }

    public String GetDisplayName() {
        return displayName;
    }

    /**
     * Restores new-game defaults, then applies this launch's explicit branch context.
     */
    public void ApplyDebugGameState() {
        DebugGameState.ResetDebugGameState();
        if (entryContext == EntryContext.LEVEL_EIGHT_FROM_LEVEL_SEVEN) {
            LevelSeven.FromLevelSeven = true;
        }
    }

    public static List<DebugLevelLaunch> GetLaunches() {
        ArrayList<DebugLevelLaunch> launches = new ArrayList<>();
        for (LevelDefinition levelDefinition : LevelDefinition.values()) {
            if (levelDefinition == LevelDefinition.LEVEL_EIGHT) {
                launches.add(new DebugLevelLaunch(levelDefinition, "Level 8 - From Level 6",
                        EntryContext.LEVEL_EIGHT_FROM_LEVEL_SIX));
                launches.add(new DebugLevelLaunch(levelDefinition, "Level 8 - From Level 7",
                        EntryContext.LEVEL_EIGHT_FROM_LEVEL_SEVEN));
            } else {
                launches.add(new DebugLevelLaunch(levelDefinition, levelDefinition.GetDisplayName(),
                        EntryContext.NEW_GAME));
            }
        }
        return Collections.unmodifiableList(launches);
    }
}
