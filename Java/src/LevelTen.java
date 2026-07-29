public class LevelTen extends BaseLevel implements ILevel{
    public LevelTen (HookshotHeroesGameEngine engine, GameImage gameImage, GameOptions gameOptions){
        super(engine, gameImage, gameOptions);
        super.NextLevels = new NextLevelInfo[] { new NextLevelInfo(new GridCell(27, 27), new CountryRoad(engine, gameImage, gameOptions)) };
    }

    @Override
    public void RenderLevel() {
        basicLevelEnvironment();

        //Draw doors
        Engine.drawImage(GameImage.DoorGreyOpenSide, 560,280);
        doorCollision(560,280);

        //Draw chest
        if (Minotaur.BossIsDead == true) {
            Engine.drawImage(GameImage.SpecialChestSprites[0], 290, 280);
        }
    }

    @Override
    public ILevel GetNextLevel() {
        return null;
    }

    @Override
    public ILevel GetPreviousLevel() {
        return new LevelNine(Engine, GameImage, GameOptions);
    }

    @Override
    public GridCell[] GetBottomStartingPos() {
        return new GridCell[]{new GridCell(25, 50), new GridCell(33, 50)};
    }

    @Override
    public GridCell[] GetTopStartingPos() {
        return new GridCell[]{new GridCell(5, 23), new GridCell(5, 33)};
    }

    @Override
    public GridCell[] GetExitGrid() {
        return new GridCell[]{ new GridCell(27, 27)};
    }

    @Override
    public GridCell GetEntryGrid() {
        return new GridCell(56, 27);
    }

    @Override
    public String GetLevelName() {
        return "Level 10";
    }

    @Override
    public void ApplyLevelMusic(GameAudio gameAudio){
        gameAudio.ApplyTheme(Engine, "lava.wav", GameOptions.MasterVolume);
    }

    @Override
    public boolean CanExit(IWorld world) {
        for (IWorldObject object : world.GetObjects()) {
            if (object.WhoAmI() == WorldObjectType.GhostWizard) {
                return false;
            }
        }
        return true;
    }
}
