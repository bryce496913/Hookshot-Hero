public class LevelFour extends BaseLevel implements ILevel{
    public boolean DoorEnterTop = true;
    public boolean DoorEnterRight = true;
    public LevelFour (HookshotHeroesGameEngine engine, GameImage gameImage, GameOptions gameOptions){
        super(engine, gameImage, gameOptions);
        super.NextLevels = new NextLevelInfo[] {
                new NextLevelInfo(new GridCell(0, 27), new LevelSix(Engine, GameImage, GameOptions)),
                new NextLevelInfo(new GridCell(27, 52), new LevelFive(Engine, GameImage, GameOptions))
        };
    }
    @Override
    public void RenderLevel() {
        basicLevelEnvironment();

        //Draw doors
        if (Minotaur.BossIsDead == true) {
            Engine.drawImage(GameImage.DoorGreyOpen, 280, 0);
            doorCollision(280, 0);
            Engine.drawImage(GameImage.DoorGreyOpenSide, 560, 280);
            doorCollision(560, 280);
        } else {
            Engine.drawImage(GameImage.DoorGreyClosed, 280, 0);
            Engine.drawImage(GameImage.DoorGreyClosedRightSide, 560, 280);
        }
        Engine.drawImage(GameImage.DoorGreyClosed, 280,560);
        doorCollision(280,560);
    }

    @Override
    public ILevel GetNextLevel() {
        if (DoorEnterTop == true) {
            Minotaur.BossIsDead = false;
            return new LevelSix(Engine, GameImage, GameOptions);
        } else if (DoorEnterRight == true) {
            Minotaur.BossIsDead = false;
            return new LevelFive(Engine, GameImage, GameOptions);
        } else {
            return null;
        }
    }


    @Override
    public ILevel GetPreviousLevel() {
        return new LevelThree(Engine, GameImage, GameOptions);
    }

    @Override
    public GridCell[] GetTopStartingPos() {
        return new GridCell[]{new GridCell(5, 23), new GridCell(5, 33)};
    }

    @Override
    public GridCell[] GetBottomStartingPos() {
        return new GridCell[]{new GridCell(50, 27), new GridCell(50, 33)};
    }

    @Override
    public GridCell[] GetExitGrid() {
        return new GridCell[]{ new GridCell(0, 27), new GridCell(27, 52)};
    }

    @Override
    public GridCell GetEntryGrid() {
        return new GridCell(56, 27);
    }

    @Override
    public String GetLevelName() {
        return "Level 4";
    }

    @Override
    public void ApplyLevelMusic(GameAudio gameAudio){
        gameAudio.ApplyTheme(Engine, "lava.wav", GameOptions.MasterVolume);
    }

    @Override
    public boolean CanExit(IWorld world) {
        for (IWorldObject object : world.GetObjects()) {
            if (object.WhoAmI() == WorldObjectType.Minotaur) {
                return false;
            }
        }
        return true;
    }
}
