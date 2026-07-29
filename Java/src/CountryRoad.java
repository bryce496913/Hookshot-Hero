public class CountryRoad extends BaseLevel implements ILevel{
    private int _idx = 0;
    public CountryRoad (HookshotHeroesGameEngine engine, GameImage gameImage, GameOptions gameOptions){
        super(engine, gameImage, gameOptions);
        super.NextLevels = new NextLevelInfo[] { new NextLevelInfo(new GridCell(0, 27), new HeroWelcome(engine, gameImage, gameOptions)) };
    }
    @Override
    public void RenderLevel() {
        //Floor
        for (int y = 0; y < GameOptions.Height - 50; y += environmentSpriteSize) {
            for (int x = 0; x < GameOptions.Width; x += environmentSpriteSize) {
                Engine.drawImage(GameImage.Grass, x, y);
            }
        }
        for (int x = 0; x < GameOptions.Width; x += environmentSpriteSize) {
            // Draw wall sprite on the top side
            drawGrassWithCollision(x, 0);

            // Draw wall sprite on the bottom side
            drawGrassWithCollision(x, GameOptions.Width - environmentSpriteSize);
            drawCastleWallFrontWithCollision(x, GameOptions.Width - environmentSpriteSize);
        }
        for (int y = 0; y < GameOptions.Width - environmentSpriteSize; y += environmentSpriteSize) {
            // Draw wall sprite on the left side
            Engine.drawImage(GameImage.Grass, 0, y);
            super.AddWallCell(0, y);

            // Draw wall sprite on the right side
            Engine.drawImage(GameImage.Grass, GameOptions.Width - 7, y);
            super.AddWallCell(GameOptions.Width - environmentSpriteSize, y);
        }
        for (int y = 50; y < GameOptions.Height - 460; y += environmentSpriteSize) {
            for (int x = 0; x < GameOptions.Width; x += environmentSpriteSize) {
                Engine.drawImage(GameImage.Cobble, x, y);
            }
        }
        for (int i = 0; i < 16; i++){
            Engine.drawImage(GameImage.Road, 250,0 + i*30);
        }
        for (int x = 0; x < 600; x += 100) {
            Engine.drawImage(GameImage.Water1, x, 250);
            Engine.drawImage(GameImage.Water1, x, 300);
        }
        for (int x = 0; x < 200; x += 70) {
            Engine.drawImage(GameImage.Cliff, x, 350);
            super.AddWallCell(x, 350);
            super.AddWallCell(x + 40, 350);
            super.AddWallCell(x, 390);
            super.AddWallCell(x + 40, 390);
        }
        Engine.drawImage(GameImage.Wood, 250,250);
        Engine.drawImage(GameImage.Market, 450, 20);
        super.AddWallCell(450, 20);
        super.AddWallCell(490, 20);
        super.AddWallCell(530, 20);
        super.AddWallCell(450, 60);
        super.AddWallCell(490, 60);
        super.AddWallCell(530, 60);
        Engine.drawImage(GameImage.Market1, 100, 100);
        super.AddWallCell(100, 100);
        super.AddWallCell(150, 100);
        super.AddWallCell(190, 100);
        Engine.drawImage(GameImage.Market2, 100, 190);
        super.AddWallCell(100, 200);
        super.AddWallCell(150, 200);
        super.AddWallCell(190, 200);
        Engine.drawImage(GameImage.Wheat, 450, 150);
        super.AddWallCell(450, 150);
        super.AddWallCell(500, 150);
        Engine.drawImage(GameImage.Bags, 390, 220);
        super.AddWallCell(390, 220);
        Engine.drawImage(GameImage.Island, 450, 275);
        super.AddWallCell(450, 275);
        Engine.drawImage(GameImage.Lake, 55, 460);

        Engine.drawImage(GameImage.CastleDoor, 290,565);
        Engine.drawImage(GameImage.CastleDoor, 305,565);

        var offset = 10;
        if (_idx / offset >= GameImage.WaterfallSprites.length) {
            _idx = 0;
        }
        Engine.drawImage(GameImage.WaterfallSprites[_idx / offset], 55, 350);
        if (!Engine.IsPause()) {
            _idx++;
        }
    }

    @Override
    public ILevel GetNextLevel() {
        return null;
    }

    @Override
    public ILevel GetPreviousLevel() {
        return null;
    }

    @Override
    public GridCell[] GetTopStartingPos() {
        return new GridCell[]{new GridCell(5, 23), new GridCell(5, 35)};
    }

    @Override
    public GridCell[] GetBottomStartingPos() {
        return new GridCell[]{new GridCell(50, 27), new GridCell(50, 33)};
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
        return "Country Road";
    }

    @Override
    public void ApplyLevelMusic(GameAudio gameAudio){
        gameAudio.ApplyTheme(Engine, "pretty-maiden-mageonduty.wav", GameOptions.MasterVolume);
    }
}
