import java.awt.event.KeyEvent;
import java.util.ArrayList;

/****************************************************************************************
 * This class creates a double player game world.
 ****************************************************************************************/
public class DoublePlayerWorldBuilder extends BaseWorldBuilder implements IWorldBuilder{
    @Override
    public IWorld Build(HookshotHeroesGameEngine engine, GameImage gameImage, GameAudio gameAudio, GameOptions options,
                        ILevel level, ArrayList<Player> players, ArrayList<Player> npcplayers) {

        var world = super.CreateWorld(engine, gameImage, gameAudio, options, level);
        var grids = level.GetStartPos() == LevelStartPos.Top ? level.GetTopStartingPos() : level.GetBottomStartingPos();
        world.CurrentLevel.RenderLevel();
        if (players != null && players.size() > 1) {
            for (var p : players) {
                p.WallCells = level.GetWallCells();
                p.LavaCells = level.GetLavaCells();
                p.OccupiedCells = level.GetOccupiedCells();
                p.AudioRequests = world.AudioRequests;
                p.EliminationRequests = world.EliminationRequests;
                p.AnimationRequests = world.AnimationRequests;
                p.World = world;
            }
            players.get(0).SetGridCell(grids[0]);
            players.get(1).SetGridCell(grids[1]);
            world.SetObjects(new IWorldObject[]
                    {
                            players.get(0),
                            players.get(1)
                    });
        } else {
            Player Lidia = new Player(CharacterNames.LIDIA, grids[0],
                    new Skin(world.GameImage.LidiaUpSprites, world.GameImage.LidiaLeftSprites, world.GameImage.LidiaRightSprites, world.GameImage.LidiaDownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                    new KeyBinding(KeyEvent.VK_W, KeyEvent.VK_A, KeyEvent.VK_D, KeyEvent.VK_S, KeyEvent.VK_X),
                    level.GetWallCells(), level.GetLavaCells(), level.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world
            );
            Player Shura = new Player(CharacterNames.SHURA, grids[1],
                    new Skin(world.GameImage.ShuraUpSprites, world.GameImage.ShuraLeftSprites, world.GameImage.ShuraRightSprites, world.GameImage.ShuraDownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                    new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                    level.GetWallCells(), level.GetLavaCells(), level.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world
            );

            if (players != null && players.size() == 1) {
                var survivor = players.get(0);
                survivor.SetGridCell(grids[0]);
                survivor.WallCells = level.GetWallCells();
                survivor.LavaCells = level.GetLavaCells();
                survivor.OccupiedCells = level.GetOccupiedCells();
                survivor.AudioRequests = world.AudioRequests;
                survivor.EliminationRequests = world.EliminationRequests;
                survivor.AnimationRequests = world.AnimationRequests;
                survivor.World = world;

                Player newPlayer;
                if (survivor.GetName() == CharacterNames.LIDIA) {
                    newPlayer = Shura;
                } else {
                    newPlayer = Lidia;
                }
                world.SetObjects(new IWorldObject[]
                        {
                                survivor,
                                newPlayer
                        });
            } else {
                world.SetObjects(new IWorldObject[]
                        {
                                Lidia,
                                Shura
                        });
            }
        }

        InitializeNPCPlayers(options, world, npcplayers, grids[0]);

        if (!(level instanceof HeroWelcome) && !(level instanceof CountryRoad)) {
            super.AddObjects(world, WorldObjectType.Mine, 5);
            super.AddObjects(world, WorldObjectType.Cabbage, 3);
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
            super.AddObjects(world, WorldObjectType.Skeleton, 2);
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
