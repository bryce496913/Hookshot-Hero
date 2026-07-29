import java.util.ArrayList;

public class LevelTwo extends BaseLevel implements ILevel{

    public LevelTwo (HookshotHeroesGameEngine engine, GameImage gameImage, GameOptions gameOptions){
        super(engine, gameImage, gameOptions);
        AddEmitter(50, 390);
        AddEmitter(500, 550);
        super.NextLevels = new NextLevelInfo[]{ new NextLevelInfo(new GridCell(0, 27), new LevelThree(Engine, GameImage, GameOptions)) };
    }
    @Override
    public void RenderLevel() {
        basicLevelEnvironment();

        // Draw internal walls
        for (int x = 40; x < 440; x += environmentSpriteSize) {
            Engine.drawImage(GameImage.wallGreyFront, x, 160);
            drawWallFrontWithCollision(x, 160);
        }
        for (int x = 80; x < 160; x += environmentSpriteSize) {
            Engine.drawImage(GameImage.wallGreyFront, x, 240);
            drawWallFrontWithCollision(x, 240);
        }
        for (int x = 360; x < 440; x += environmentSpriteSize) {
            Engine.drawImage(GameImage.wallGreyFront, x, 200);
            drawWallFrontWithCollision(x, 200);
            Engine.drawImage(GameImage.wallGreyFront, x, 240);
            drawWallFrontWithCollision(x, 240);
        }

        // Draw Lava
        for (int x = 40; x < 560; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 320);
            drawLavaWithCollision(x, 360);
            drawLavaWithCollision(x, 400);
        }
        for (int x = 360; x < 560; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 440);
            drawLavaWithCollision(x, 480);
            drawLavaWithCollision(x, 520);
        }
        for (int x = 200; x < 320; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 200);
            drawLavaWithCollision(x, 240);
            drawLavaWithCollision(x, 280);
        }

        //Draw doors
        Engine.drawImage(GameImage.DoorGreyOpen, 280,0);
        doorCollision(280,0);
        Engine.drawImage(GameImage.DoorGreyClosed, 280,560);
        doorCollision(280,560);
    }

    @Override
    public ILevel GetNextLevel() {
        return new LevelThree(Engine, GameImage, GameOptions);
    }

    @Override
    public ILevel GetPreviousLevel() {
        return new LevelOne(Engine, GameImage, GameOptions);
    }

    @Override
    public GridCell[] GetTopStartingPos() {
        return new GridCell[]{new GridCell(5, 23), new GridCell(5, 33)};
    }

    @Override
    public GridCell[] GetBottomStartingPos() {
        return new GridCell[]{new GridCell(50, 27), new GridCell(50, 30)};
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
        return "Level 2";
    }
}
