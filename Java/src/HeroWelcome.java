public class HeroWelcome extends BaseLevel implements ILevel{
    public HeroWelcome (HookshotHeroesGameEngine engine, GameImage gameImage, GameOptions gameOptions){
        super(engine, gameImage, gameOptions);
        AddChest(65, 50, true, "Well done!", false);
        AddChest(505, 50, true, "Well done!", false);
        AddChest(505, 500, true, "Well done!", false);
        super.NextLevels = new NextLevelInfo[] { new NextLevelInfo(new GridCell(0, 27), null) };
    }
    @Override
    public void RenderLevel() {
        //Floor
        for (int y = 0; y < GameOptions.Width - 50; y += 32) {
            for (int x = 0; x < GameOptions.Height; x += 32) {
                Engine.drawImage(GameImage.CastleFloor, x, y);
            }
        }

        Engine.drawImage(GameImage.CastleRedCarpet, 275,35);
        for (int i = 0; i < 15; i++){
            Engine.drawImage(GameImage.CastleCarpet, 283,100 + i*32);
        }

        for (int x = 0; x < GameOptions.Width; x += environmentSpriteSize) {
            // Draw wall sprite on the top side
            drawCastleWallFrontWithCollision(x, 0);

            // Draw wall sprite on the bottom side
            drawCastleWallFrontWithCollision(x, GameOptions.Width - environmentSpriteSize);
        }
        for (int y = 0; y < GameOptions.Width - environmentSpriteSize; y += environmentSpriteSize) {
            // Draw wall sprite on the left side
            Engine.drawImage(GameImage.CastleSideWall, 0, y);
            super.AddWallCell(0, y);

            // Draw wall sprite on the right side
            Engine.drawImage(GameImage.CastleSideWall, GameOptions.Width - 7, y);
            super.AddWallCell(GameOptions.Width - environmentSpriteSize, y);
        }

        for (int i = 0; i < 5; i++){
            drawCastleColumnWithCollision(240, 100 + i*100);
            drawCastleColumnWithCollision(355, 100 + i*100);
        }

        Engine.drawImage(GameImage.CastleWallFlags, 150,5);
        Engine.drawImage(GameImage.CastleWallFlags, 430,5);
        Engine.drawImage(GameImage.CastleKnight, 100,10);
        Engine.drawImage(GameImage.CastleKnight, 500,10);
        Engine.drawImage(GameImage.CastleDesk, 290,100);
        Engine.drawImage(GameImage.CastleBookShelf, 250,5);
        Engine.drawImage(GameImage.CastleBookShelf, 339,5);

        for (int i = 0; i < 5; i++){
            Engine.drawImage(GameImage.CastleFlower1, 5,5 + i*120);
            Engine.drawImage(GameImage.CastleFlower1, 575,5 + i*120);
            Engine.drawImage(GameImage.CastleFlower2, 5,50 + i*120);
            Engine.drawImage(GameImage.CastleFlower2, 575,50 + i*120);
        }

        Engine.drawImage(GameImage.SpecialChestSprites[0], 65, 50);
        Engine.drawImage(GameImage.SpecialChestSprites[0], 505, 50);
        Engine.drawImage(GameImage.SilverChest, 505, 500);
        Engine.drawImage(GameImage.Barrels, 65, 500, 90, 45);

        Engine.drawImage(GameImage.CastleDoor, 290,565);
        Engine.drawImage(GameImage.CastleDoor, 305,565);

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
        return "Hero's Welcome";
    }
}
