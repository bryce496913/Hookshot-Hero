/**
 * The complete set of playable maps exposed by the debug level selector.
 * Add new level implementations here to make them available from the main menu.
 */
public enum LevelDefinition {
    LEVEL_ONE("Level 1"),
    LEVEL_TWO("Level 2"),
    LEVEL_THREE("Level 3"),
    LEVEL_FOUR("Level 4"),
    LEVEL_FIVE("Level 5"),
    LEVEL_SIX("Level 6"),
    LEVEL_SEVEN("Level 7"),
    LEVEL_EIGHT("Level 8"),
    LEVEL_NINE("Level 9"),
    LEVEL_TEN("Level 10"),
    COUNTRY_ROAD("Country Road"),
    HERO_WELCOME("Hero's Welcome");

    private final String displayName;

    LevelDefinition(String displayName) {
        this.displayName = displayName;
    }

    public String GetDisplayName() {
        return displayName;
    }

    public ILevel Create(HookshotHeroesGameEngine engine, GameImage gameImage, GameOptions gameOptions) {
        switch (this) {
            case LEVEL_ONE:
                return new LevelOne(engine, gameImage, gameOptions);
            case LEVEL_TWO:
                return new LevelTwo(engine, gameImage, gameOptions);
            case LEVEL_THREE:
                return new LevelThree(engine, gameImage, gameOptions);
            case LEVEL_FOUR:
                return new LevelFour(engine, gameImage, gameOptions);
            case LEVEL_FIVE:
                return new LevelFive(engine, gameImage, gameOptions);
            case LEVEL_SIX:
                return new LevelSix(engine, gameImage, gameOptions);
            case LEVEL_SEVEN:
                return new LevelSeven(engine, gameImage, gameOptions);
            case LEVEL_EIGHT:
                return new LevelEight(engine, gameImage, gameOptions);
            case LEVEL_NINE:
                return new LevelNine(engine, gameImage, gameOptions);
            case LEVEL_TEN:
                return new LevelTen(engine, gameImage, gameOptions);
            case COUNTRY_ROAD:
                return new CountryRoad(engine, gameImage, gameOptions);
            case HERO_WELCOME:
                return new HeroWelcome(engine, gameImage, gameOptions);
            default:
                throw new IllegalStateException("No level is registered for " + this);
        }
    }
}
