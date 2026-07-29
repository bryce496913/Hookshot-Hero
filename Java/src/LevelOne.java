import java.util.ArrayList;

public class LevelOne extends BaseLevel implements ILevel{

    public LevelOne (HookshotHeroesGameEngine engine, GameImage gameImage, GameOptions gameOptions){
        super(engine, gameImage, gameOptions);
        AddEmitter(100, 300);
        AddEmitter(500, 350);
        AddChest(290, 440, true, "Welcome Heroine!! Use X key or . key to launch grapple. You can use grapple to jump across lava / attack enemy and fetch items. Each level has chests that gives you extra score and health. Food barrels can also replenish your health. Beware of bombs.", true);
        super.NextLevels = new NextLevelInfo[]{ new NextLevelInfo(new GridCell(0, 27), new LevelTwo(Engine, GameImage, GameOptions)) };
    }

    @Override
    public void RenderLevel() {
        basicLevelEnvironment();

        // Draw Lava
        for (int x = 40; x < 560; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 240);
            drawLavaWithCollision(x, 280);
            drawLavaWithCollision(x, 320);
        }

        //Internal walls
        for (int x = 200; x < 400; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 160);
        }

        //Draw doors
        Engine.drawImage(GameImage.DoorGreyOpen, 280,0);
        doorCollision(280,0);
        Engine.drawImage(GameImage.DoorGreyClosed, 280,560);
        doorCollision(280,560);

        //Draw chest
        Engine.drawImage(GameImage.SpecialChestSprites[0], 290, 440);
    }

    @Override
    public ILevel GetNextLevel() {
        return new LevelTwo(Engine, GameImage, GameOptions);
    }

    @Override
    public ILevel GetPreviousLevel() {
        return null;
    }

    @Override
    public GridCell[] GetBottomStartingPos() {
        return new GridCell[]{new GridCell(50, 27), new GridCell(50, 33)};
    }

    @Override
    public GridCell[] GetTopStartingPos() {
        return new GridCell[]{new GridCell(5, 23), new GridCell(5, 35)};
    }

    @Override
    public GridCell[] GetExitGrid() {
        return new GridCell[]{ new GridCell(0, 27)};
    }

    @Override
    public GridCell GetEntryGrid() {
        return new GridCell(56, 27);
    }

    @Override
    public String GetLevelName() {
        return "Level 1";
    }

    @Override
    public void ApplyLevelMusic(GameAudio gameAudio){
        gameAudio.ApplyTheme(Engine, "Atmosphere.wav", GameOptions.MasterVolume);
    }
}
