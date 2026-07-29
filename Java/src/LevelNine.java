import java.util.ArrayList;

public class LevelNine extends BaseLevel implements ILevel{
    public LevelNine (HookshotHeroesGameEngine engine, GameImage gameImage, GameOptions gameOptions){
        super(engine, gameImage, gameOptions);
        AddEmitter(135, 405);
        AddEmitter(300, 90);
        AddChest(40, 520, true, "You made it!", false);
        super.NextLevels = new NextLevelInfo[] { new NextLevelInfo(new GridCell(7, 1), new LevelTen(Engine, GameImage, GameOptions)) };
    }

    @Override
    public void RenderLevel() {
        basicLevelEnvironment();

        for (int x = 80; x < 200; x += environmentSpriteSize) {
            for (int y = 400; y < 480; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 120; x < 200; x += environmentSpriteSize) {
            for (int y = 200; y < 280; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int y = 80; y < 200; y += environmentSpriteSize) {
            drawLavaWithCollision(200, y);
        }
        for (int y = 360; y < 480; y += environmentSpriteSize) {
            drawLavaWithCollision(280, y);
        }
        for (int y = 400; y < 520; y += environmentSpriteSize) {
            drawLavaWithCollision(520, y);
        }
        for (int x = 120; x < 200; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 120);
        }
        for (int x = 240; x < 320; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 80);
        }
        for (int x = 240; x < 360; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 240);
        }
        for (int x = 400; x < 520; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 200);
        }
        for (int x = 320; x < 440; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 160);
        }
        for (int x = 360; x < 480; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 320);
        }
        for (int x = 200; x < 280; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 480);
        }
        for (int x = 320; x < 400; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 440);
        }
        for (int x = 400; x < 520; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 520);
        }
        drawLavaWithCollision(80, 200);
        drawLavaWithCollision(80, 480);
        drawLavaWithCollision(160, 360);
        drawLavaWithCollision(360, 480);
        drawLavaWithCollision(400, 400);

        //Draw internal walls
        for (int x = 480; x < 560; x += environmentSpriteSize) {
            for (int y = 40; y < 200; y += environmentSpriteSize) {
                drawWallFrontWithCollision(x, y);
            }
        }
        for (int x = 200; x < 280; x += environmentSpriteSize) {
            for (int y = 320; y < 400; y += environmentSpriteSize) {
                drawWallFrontWithCollision(x, y);
            }
        }
        for (int x = 80; x < 560; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 280);
        }
        for (int x = 40; x < 160; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 40);
        }
        for (int x = 40; x < 200; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 160);
        }
        for (int x = 240; x < 320; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 40);
        }
        for (int x = 240; x < 360; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 200);
        }
        for (int x = 80; x < 160; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 360);
        }
        for (int x = 200; x < 280; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 520);
        }
        for (int x = 400; x < 520; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 480);
        }
        for (int x = 320; x < 480; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 360);
        }
        for (int y = 440; y < 520; y += environmentSpriteSize) {
            drawWallFrontWithCollision(40, y);
        }
        for (int y = 480; y < 560; y += environmentSpriteSize) {
            drawWallFrontWithCollision(320, y);
        }
        for (int y = 400; y < 520; y += environmentSpriteSize) {
            drawWallFrontWithCollision(480, y);
        }
        drawWallFrontWithCollision(40, 120);
        drawWallFrontWithCollision(120, 80);
        drawWallFrontWithCollision(80, 240);
        drawWallFrontWithCollision(80, 320);
        drawWallFrontWithCollision(120, 480);
        drawWallFrontWithCollision(200, 440);
        drawWallFrontWithCollision(320, 400);
        drawWallFrontWithCollision(520, 320);
        drawWallFrontWithCollision(400, 240);
        drawWallFrontWithCollision(240, 160);
        drawWallFrontWithCollision(320, 120);
        drawWallFrontWithCollision(440, 40);
        drawWallFrontWithCollision(440, 80);
        drawWallFrontWithCollision(120, 320);
        drawWallFrontWithCollision(160, 320);
        drawWallFrontWithCollision(360, 80);
        drawWallFrontWithCollision(360, 120);

        //Draw doors
        Engine.drawImage(GameImage.DoorGreyOpenLeftSide, 0,80);
        doorCollision(0,80);
        Engine.drawImage(GameImage.DoorGreyClosed, 280,560);
        doorCollision(280,560);

        //Draw chest
        Engine.drawImage(GameImage.ChestSide, 40, 520);
    }

    @Override
    public ILevel GetNextLevel() {
        return new LevelTen(Engine, GameImage, GameOptions);
    }

    @Override
    public ILevel GetPreviousLevel() {
        return new LevelEight(Engine, GameImage, GameOptions);
    }

    @Override
    public GridCell[] GetBottomStartingPos() {
        return new GridCell[]{new GridCell(50, 27), new GridCell(50, 27)};
    }

    @Override
    public GridCell[] GetTopStartingPos() {
        return new GridCell[]{new GridCell(5, 23), new GridCell(5, 23)};
    }

    @Override
    public GridCell[] GetExitGrid() {
        return new GridCell[]{ new GridCell(7, 3)};
    }

    @Override
    public GridCell GetEntryGrid() {
        return new GridCell(56, 27);
    }

    @Override
    public String GetLevelName() {
        return "Level 9";
    }
}
