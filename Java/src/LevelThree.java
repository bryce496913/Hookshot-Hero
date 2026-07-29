public class LevelThree extends BaseLevel implements ILevel {

    public LevelThree (HookshotHeroesGameEngine engine, GameImage gameImage, GameOptions gameOptions){
        super(engine, gameImage, gameOptions);
        AddEmitter(50, 90);
        AddEmitter(200, 560);
        AddEmitter(492, 425);
        AddChest(80, 520, true, "You made it!", false);
        super.NextLevels = new NextLevelInfo[]{ new NextLevelInfo(new GridCell(0, 27), new LevelFour(Engine, GameImage, GameOptions)) };
    }
    @Override
    public void RenderLevel() {
        basicLevelEnvironment();

        // Draw internal walls
        for (int x = 240; x < 480; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 120);
        }
        for (int y = 40; y < 120; y += environmentSpriteSize) {
            drawWallFrontWithCollision(240, y);
        }
        for (int y = 400; y < 560; y += environmentSpriteSize) {
            drawWallFrontWithCollision(240, y);
        }
        for (int x = 240; x < 480; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 400);
        }
        for (int x = 320; x < 560; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 240);
        }
        for (int y = 320; y <= 360; y += 40) {
            for (int x = 40; x <= 40; x += 40) {
                drawWallFrontWithCollision(x, y);
            }
        }
        drawWallFrontWithCollision(320, 280);
        drawWallFrontWithCollision(40, 280);
        drawWallFrontWithCollision(80, 280);
        drawWallFrontWithCollision(320, 320);
        drawWallFrontWithCollision(280, 320);

        // Draw Lava
        for (int y = 40; y < 280; y += environmentSpriteSize) {
            for (int x = 40; x < 220; x += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int y = 320; y < 560; y += environmentSpriteSize) {
            for (int x = 120; x < 220; x += 20) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 40; x <= 40; x += environmentSpriteSize) {
            for (int y = 400; y <= 520; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 400; x <= 480; x += environmentSpriteSize) {
            for (int y = 280; y <= 360; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 520; x <= 520; x += environmentSpriteSize) {
            for (int y = 320; y <= 400; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int y = 400; y <= 440; y += environmentSpriteSize) {
            drawLavaWithCollision(80, y);
        }
        for (int y = 80; y <= 120; y += environmentSpriteSize) {
            for (int x = 480; x <= 540; x += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 120; x < 240; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 280);
        }
        drawLavaWithCollision(480, 400);

        //Draw doors
        Engine.drawImage(GameImage.DoorGreyOpen, 280,0);
        doorCollision(280,0);
        Engine.drawImage(GameImage.DoorGreyClosed, 280,560);
        doorCollision(280,560);

        //Draw chest
        Engine.drawImage(GameImage.ChestBack, 80, 520);
    }

    @Override
    public ILevel GetNextLevel() {
        return new LevelFour(Engine, GameImage, GameOptions);
    }

    @Override
    public ILevel GetPreviousLevel() {
        return new LevelTwo(Engine, GameImage, GameOptions);
    }

    @Override
    public GridCell[] GetTopStartingPos() {
        return new GridCell[]{new GridCell(5, 23), new GridCell(5, 33)};
    }

    @Override
    public GridCell[] GetBottomStartingPos() {
        return new GridCell[]{new GridCell(50, 27), new GridCell(50, 37)};
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
        return "Level 3";
    }
}
