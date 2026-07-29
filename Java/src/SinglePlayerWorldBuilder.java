import java.awt.event.KeyEvent;
import java.util.ArrayList;

/****************************************************************************************
 * This class creates a single player game world.
 ****************************************************************************************/
public class SinglePlayerWorldBuilder extends BaseWorldBuilder implements IWorldBuilder{
    @Override
    public IWorld Build(HookshotHeroesGameEngine engine, GameImage gameImage, GameAudio gameAudio, GameOptions options,
                        ILevel level, ArrayList<Player> players, ArrayList<Player> npcplayers) {

        var world = super.CreateWorld(engine, gameImage, gameAudio, options, level);
        var grid = level.GetStartPos() == LevelStartPos.Top ? level.GetTopStartingPos()[0] : level.GetBottomStartingPos()[0];
        world.CurrentLevel.RenderLevel();
        Player player;
        if (players != null && players.size() > 0) {
            player = players.get(0);
            player.WallCells = level.GetWallCells();
            player.LavaCells = level.GetLavaCells();
            player.OccupiedCells = level.GetOccupiedCells();
            player.AudioRequests = world.AudioRequests;
            player.EliminationRequests = world.EliminationRequests;
            player.AnimationRequests = world.AnimationRequests;
            player.World = world;
            player.SetGridCell(grid);
        } else {
            player = new Player(CharacterNames.LIDIA, grid,
                    new Skin(world.GameImage.LidiaUpSprites, world.GameImage.LidiaLeftSprites, world.GameImage.LidiaRightSprites, world.GameImage.LidiaDownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                    new KeyBinding(KeyEvent.VK_W, KeyEvent.VK_A, KeyEvent.VK_D, KeyEvent.VK_S, KeyEvent.VK_X),
                    level.GetWallCells(), level.GetLavaCells(), level.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world
            );
        }

        var objects = new ArrayList<IWorldObject>();
        objects.add(player);
        world.SetObjects(objects);

        InitializeNPCPlayers(options, world, npcplayers, grid);

        if (!(level instanceof HeroWelcome) && !(level instanceof CountryRoad) ) {
            super.AddObjects(world, WorldObjectType.Mine, 3);
            super.AddObjects(world, WorldObjectType.Cabbage, 2);
            super.AddObjects(world, WorldObjectType.Coin, 10);
        }

        if (options.EnableBouncingBalls) {
            super.AddObjects(world, WorldObjectType.Ball, 5);
        }
        if (level instanceof LevelFour) {
            super.AddObjects(world, WorldObjectType.Minotaur, 1);
            level.ApplyLevelMusic(gameAudio);
        } else if (level instanceof LevelTen) {
            super.AddObjects(world, WorldObjectType.GhostWizard, 1);
            level.ApplyLevelMusic(gameAudio);
        } else if (level instanceof LevelFive) {
            level.ApplyLevelMusic(gameAudio);
        } else if (level instanceof LevelSix) {
            level.ApplyLevelMusic(gameAudio);
        } else if (level instanceof LevelOne) {
            level.ApplyLevelMusic(gameAudio);
            if (options.MissionMode){
                super.AddObjects(world, WorldObjectType.Guide, 1);
            }
        }
        if (!(level instanceof LevelOne) && !(level instanceof LevelFour) && !(level instanceof LevelTen) && !(level instanceof HeroWelcome) && !(level instanceof CountryRoad) ){
            super.AddObjects(world, WorldObjectType.Skeleton, 1);
            super.AddObjects(world, WorldObjectType.FlyingTerror, 1);
        }
        if (level instanceof HeroWelcome) {
            super.AddBGC(world, NPCType.King, 1);
            super.AddBGC(world, NPCType.Queen, 1);
            super.AddBGC(world, NPCType.Princess, 1);
            super.AddBGC(world, NPCType.Prince, 1);
            super.AddBGC(world, NPCType.Aristocrat, 5);
        }
        if (level instanceof CountryRoad) {
            super.AddBGC(world, NPCType.Child, 9);
            super.AddBGC(world, NPCType.Old, 5);
            super.AddBGC(world, NPCType.Townfolk, 15);
            super.AddObjects(world, WorldObjectType.Cabbage, 5);
            super.AddObjects(world, WorldObjectType.Coin, 15);
            if (world.GameOptions.MissionMode) {
                world.Objects.add(new Guide(CharacterNames.SARAH, "You made it!!!", new GridCell(50, 39),
                        new Skin(world.GameImage.SarahSprites, world.CELL_WIDTH, world.CELL_HEIGHT)));
            }
            level.ApplyLevelMusic(gameAudio);
        }
        return world;
    }
}