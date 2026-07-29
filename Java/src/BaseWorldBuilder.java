import java.awt.*;
import java.awt.event.KeyEvent;
import java.util.ArrayList;
import java.util.Random;

/****************************************************************************************
 * This class is the world builder base class.
 ****************************************************************************************/
public class BaseWorldBuilder {
    protected int startOffset = 5, endOffset = 10;

    public World CreateWorld(HookshotHeroesGameEngine engine, GameImage gameImage, GameAudio gameAudio, GameOptions options, ILevel level) {

        return new World(options.Width, options.Height, engine, gameImage, gameAudio, options, level);
    }

    // Add objects to the world.
    public void AddObjects(World world, WorldObjectType type, int count) {
        for (int i = 0; i < count; i++) {
            if (type == WorldObjectType.Apple) {
                world.Objects.add(new Apple(java.util.UUID.randomUUID().toString(), GridCell.GetRandomCell(startOffset, world.GridRows - endOffset, startOffset, world.GridColumns - endOffset,
                        world.CurrentLevel.GetOccupiedCells()),
                        new Skin(world.GameImage.Apple, world.CELL_WIDTH, world.CELL_HEIGHT)));
            }
            if (type == WorldObjectType.Mine) {
                world.Objects.add(new Mine(java.util.UUID.randomUUID().toString(), GridCell.GetRandomCell(world.CurrentLevel.GetUnoccupiedCells()),
                        new Skin(world.GameImage.BombSprites, world.CELL_WIDTH, world.CELL_HEIGHT)));
            }
            if (type == WorldObjectType.Ball) {
                var startX = 10;
                var startY = 10;
                var radius = 10;
                var r = new Random();
                var ball = new Ball("Ball" + i, radius, world.CELL_WIDTH, world.CELL_HEIGHT, world.AudioRequests, world.AnimationRequests, world.EliminationRequests);
                ball.Position = new Vector2D(startX + radius * 3 * i, startY);
                ball.Velocity = new Vector2D(r.nextDouble(500), r.nextDouble(500));
                ball.Acceleration = new Vector2D(0, Ball.G);
                ball.Color = new Color(r.nextInt(256), r.nextInt(256), r.nextInt(256));
                world.Objects.add(ball);
            }
            if (type == WorldObjectType.Broccoli) {
                world.Objects.add(new Broccoli(java.util.UUID.randomUUID().toString(), GridCell.GetRandomCell(startOffset, world.GridRows - endOffset, startOffset, world.GridColumns - endOffset,
                        world.CurrentLevel.GetOccupiedCells()),
                        new Skin(world.GameImage.Broccoli, world.CELL_WIDTH, world.CELL_HEIGHT)));
            }
            if (type == WorldObjectType.Coin) {
                world.Objects.add(new Coin(java.util.UUID.randomUUID().toString(), GridCell.GetRandomCell(world.CurrentLevel.GetUnoccupiedCells()),
                        new Skin(world.GameImage.CoinSprites, world.CELL_WIDTH, world.CELL_HEIGHT)));
            }
            if (type == WorldObjectType.Cabbage) {
                world.Objects.add(new Cabbage(java.util.UUID.randomUUID().toString(), GridCell.GetRandomCell(world.CurrentLevel.GetUnoccupiedCells()),
                        new Skin(world.GameImage.Cabbage, world.CELL_WIDTH, world.CELL_HEIGHT)));
            }
            if (type == WorldObjectType.Minotaur) {
                world.Objects.add(new Minotaur("Minotaur", new GridCell(25, 25),
                        new Skin(world.GameImage.MinotaurUpSprites, world.GameImage.MinotaurLeftSprites, world.GameImage.MinotaurRightSprites, world.GameImage.MinotaurDownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world
                ));
            }
            if (type == WorldObjectType.GhostWizard) {
                world.Objects.add(new GhostWizard("Ghost Wizard", new GridCell(25, 25),
                        new Skin(world.GameImage.MinotaurWithAxeUpSprites, world.GameImage.MinotaurWithAxeLeftSprites, world.GameImage.MinotaurWithAxeRightSprites, world.GameImage.MinotaurWithAxeDownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world.SpawnRequests, world
                ));
            }
            if (type == WorldObjectType.Skeleton) {
                // Can move across lava grids.
                var exit = world.CurrentLevel.GetNextLevelInfo()[0].Exit;
                if (world.CurrentLevel instanceof LevelEight) {
                    exit.Row += 1;
                    exit.Column -= 3;
                }
                world.Objects.add(new Skeleton("Lava Guard", exit,
                        new Skin(world.GameImage.SkeletonUpSprites, world.GameImage.SkeletonLeftSprites, world.GameImage.SkeletonRightSprites, world.GameImage.SkeletonDownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), new ArrayList<>(), world.CurrentLevel.GetWallCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world
                ));
            }
            if (type == WorldObjectType.FlyingTerror) {
                // Can move across lava grids.
                world.Objects.add(new FlyingTerror("Flying Terror", world.CurrentLevel.GetNextLevelInfo()[0].Exit,
                        new Skin(world.GameImage.FTUpSprites, world.GameImage.FTLeftSprites, world.GameImage.FTRightSprites, world.GameImage.FTDownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        new ArrayList<>(), new ArrayList<>(), new ArrayList<>(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world
                ));
            }
            if (type == WorldObjectType.NPC) {
                // Can move across lava grids.
                world.Objects.add(new NPCPlayer("Ava", world.CurrentLevel.GetBottomStartingPos()[0],
                        new Skin(world.GameImage.AvaUpSprites, world.GameImage.AvaLeftSprites, world.GameImage.AvaRightSprites, world.GameImage.AvaDownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world
                ));
            }
            if (type == WorldObjectType.Guide) {
                world.Objects.add(new Guide(CharacterNames.SARAH, SpeechService.MISSION_GUIDE_SARAH, new GridCell(50, 39),
                        new Skin(world.GameImage.SarahSprites, world.CELL_WIDTH, world.CELL_HEIGHT)));
            }
        }
    }

    // Initialize NPC player.
    public void InitializeNPCPlayers(GameOptions options, World world, ArrayList<Player> npcplayers, GridCell grid) {
        Player npc;
        if (options.MissionMode && npcplayers != null && npcplayers.size() > 0) {

            // Strange problems here, it seems the reference to the new occupied arrays are never copied to the npc object.
            // Framework issue??
            /*npc = npcplayers.get(0);
            npc.WallCells = world.CurrentLevel.GetWallCells();
            npc.LavaCells = world.CurrentLevel.GetLavaCells();
            npc.OccupiedCells = world.CurrentLevel.GetOccupiedCells();
            npc.AudioRequests = world.AudioRequests;
            npc.EliminationRequests = world.EliminationRequests;
            npc.AnimationRequests = world.AnimationRequests;
            npc.World = world;
            npc.SetGridCell(grid);
            world.Objects.add(npc);*/

            AddObjects(world, WorldObjectType.NPC, 1);
            npc = npcplayers.get(0);
            var npcnew = world.GetNPCPlayers().get(0);
            npcnew.Score = npc.Score;
            npcnew.SetHealth(npc.GetHealth());
        } else if (options.MissionMode && npcplayers == null) {
            AddObjects(world, WorldObjectType.NPC, 1);
        }
    }

    // Add Background Characters.
    public void AddBGC(World world, NPCType type, int count){
        for (int i = 0; i < count; i++) {
            if (type == NPCType.Aristocrat) {
                var sprites = world.GameImage.GetRandomNPC(world.GameImage.Aristocrats);
                world.Objects.add(new BGCPlayer("Aristocrat", GridCell.GetRandomCell(world.CurrentLevel.GetUnoccupiedCells()),
                        new Skin(sprites.UpSprites, sprites.LeftSprites, sprites.RightSprites, sprites.DownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world, new BGCSimpleStateMachine()
                ));
            }
            if (type == NPCType.King) {
                var sprites = world.GameImage.GetRandomNPC(world.GameImage.Kings);
                world.Objects.add(new BGCPlayer("King", new GridCell(0, 27),
                        new Skin(sprites.UpSprites, sprites.LeftSprites, sprites.RightSprites, sprites.DownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world, new BGCSimpleStateMachine()
                ));
            }
            if (type == NPCType.Queen) {
                var sprites = world.GameImage.GetRandomNPC(world.GameImage.Queens);
                world.Objects.add(new BGCPlayer("Queen", new GridCell(0, 27),
                        new Skin(sprites.UpSprites, sprites.LeftSprites, sprites.RightSprites, sprites.DownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world, new BGCSimpleStateMachine()
                ));
            }
            if (type == NPCType.Prince) {
                var sprites = world.GameImage.GetRandomNPC(world.GameImage.Princes);
                world.Objects.add(new BGCPlayer("Prince", new GridCell(2, 25),
                        new Skin(sprites.UpSprites, sprites.LeftSprites, sprites.RightSprites, sprites.DownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world, new BGCSimpleStateMachine()
                ));
            }
            if (type == NPCType.Princess) {
                var sprites = world.GameImage.GetRandomNPC(world.GameImage.Princesses);
                world.Objects.add(new BGCPlayer("Princess", new GridCell(2, 33),
                        new Skin(sprites.UpSprites, sprites.LeftSprites, sprites.RightSprites, sprites.DownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world, new BGCSimpleStateMachine()
                ));
            }
            if (type == NPCType.Child) {
                var sprites = world.GameImage.GetRandomNPC(world.GameImage.Kids);
                world.Objects.add(new BGCPlayer("Child", new GridCell(3, 20 + i*2),
                        new Skin(sprites.UpSprites, sprites.LeftSprites, sprites.RightSprites, sprites.DownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world, new BGCSimpleStateMachine()
                ));
            }
            if (type == NPCType.Old) {
                var sprites = world.GameImage.GetRandomNPC(world.GameImage.Seniors);
                world.Objects.add(new BGCPlayer("Senior", new GridCell(2, 20 + i*2),
                        new Skin(sprites.UpSprites, sprites.LeftSprites, sprites.RightSprites, sprites.DownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world, new BGCSimpleStateMachine()
                ));
            }
            if (type == NPCType.Townfolk) {
                var sprites = world.GameImage.GetRandomNPC(world.GameImage.People);
                world.Objects.add(new BGCPlayer("Townfolk", new GridCell(5, 10 + i*2),
                        new Skin(sprites.UpSprites, sprites.LeftSprites, sprites.RightSprites, sprites.DownSprites, world.GameImage.Health, world.CELL_WIDTH, world.CELL_HEIGHT),
                        new KeyBinding(KeyEvent.VK_UP, KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT, KeyEvent.VK_DOWN, KeyEvent.VK_PERIOD),
                        world.CurrentLevel.GetWallCells(), world.CurrentLevel.GetLavaCells(), world.CurrentLevel.GetOccupiedCells(), world.AudioRequests, world.EliminationRequests, world.AnimationRequests, world, new BGCSimpleStateMachine()
                ));
            }
        }
    }
}
