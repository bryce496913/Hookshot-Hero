public class DebugLevelLaunchTest {
    private static void Assert(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    private static DebugLevelLaunch FindLaunch(String displayName) {
        for (DebugLevelLaunch launch : DebugLevelLaunch.GetLaunches()) {
            if (launch.GetDisplayName().equals(displayName)) {
                return launch;
            }
        }
        throw new AssertionError("Missing debug launch: " + displayName);
    }

    private static void AssertStart(GridCell actual, int expectedRow, int expectedColumn, String message) {
        Assert(actual.Row == expectedRow && actual.Column == expectedColumn,
                message + ": got (" + actual.Row + ", " + actual.Column + ")");
    }

    public static void main(String[] args) {
        DebugLevelLaunch levelFour = FindLaunch("Level 4");
        DebugLevelLaunch levelEightFromSix = FindLaunch("Level 8 - From Level 6");
        DebugLevelLaunch levelEightFromSeven = FindLaunch("Level 8 - From Level 7");
        LevelEight levelEight = new LevelEight(null, null, null);

        Minotaur.BossIsDead = true;
        LevelSeven.FromLevelSeven = true;
        levelFour.ApplyDebugGameState();
        Assert(!Minotaur.BossIsDead, "Level 4 inherited a defeated boss");
        Assert(!LevelSeven.FromLevelSeven, "A normal debug launch did not reset its entry context");

        levelEightFromSix.ApplyDebugGameState();
        AssertStart(levelEight.GetBottomStartingPos()[0], 27, 5,
                "Level 8 from Level 6 used the wrong start");

        levelEightFromSeven.ApplyDebugGameState();
        AssertStart(levelEight.GetBottomStartingPos()[0], 50, 27,
                "Level 8 from Level 7 used the wrong start");

        Minotaur.BossIsDead = true;
        levelEightFromSix.ApplyDebugGameState();
        Assert(!Minotaur.BossIsDead, "Repeated launch retained boss state");
        AssertStart(levelEight.GetBottomStartingPos()[0], 27, 5,
                "Repeated Level 8 launch retained its previous branch");
    }
}
