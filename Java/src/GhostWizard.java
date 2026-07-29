import java.awt.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedList;
import java.util.Random;

/****************************************************************************************
 * This class is the GhostWizard class.
 ****************************************************************************************/
public class GhostWizard implements IWorldObject {
    // Player health.
    public static final int MAX_LIFE = 10;
    // Visibility range.
    public static final int SIGHT = 25;
    // A list of cells occupied by the player.
    private final ArrayList<GridCell> _body;
    // Direction of player.
    private PlayerDirection _direction;
    // Skin.
    private final Skin _skin;
    // Keyboard control binding. Each player can have different binding.
    private final KeyBinding _keyBinding;
    // Occupied cells from level.
    public ArrayList<GridCell> LavaCells;
    public ArrayList<GridCell> WallCells;
    public ArrayList<GridCell> OccupiedCells;
    private final String _name;
    private GridCell _lastCell = null;
    // Number of lives
    private int _lives = 10;
    private int _spriteIndex = 0;
    private ObjectImage _image = null;
    private boolean _isGrappling = false;
    public LinkedList<AudioRequest> AudioRequests;
    public LinkedList<IWorldObject> EliminationRequests;
    public LinkedList<IWorldObject> SpawnRequests;
    public ArrayList<AnimationRequest> AnimationRequests;
    public IWorld World;
    public final IStateMachine StateMachine;
    private double x;
    private double y;
    private double velocityX;
    private double velocityY;


    public GhostWizard(String name, GridCell startCell, Skin skin, KeyBinding keyBinding,
                       ArrayList<GridCell> wallCells, ArrayList<GridCell> lavaCells, ArrayList<GridCell> occupiedCells,
                       LinkedList<AudioRequest> audioRequests, LinkedList<IWorldObject> eliminationRequests, ArrayList<AnimationRequest> animationRequests,
                       LinkedList<IWorldObject> spawnRequests, IWorld world) {
        _name = name;
        _skin = skin;
        _direction = PlayerDirection.Right;
        _keyBinding = keyBinding;
        _body = new ArrayList<>();
        _body.add(new GridCell(startCell.Row, startCell.Column));
        _image = new ObjectImage(skin.DownSprites[0]);
        WallCells = wallCells;
        LavaCells = lavaCells;
        OccupiedCells = occupiedCells;
        AudioRequests = audioRequests;
        EliminationRequests = eliminationRequests;
        SpawnRequests = spawnRequests;
        AnimationRequests = animationRequests;
        World = world;
        StateMachine = new NPCSimpleStateMachine();
    }

    // Move the player.
    // Use the direction of the player to decide the movement after key press.
    // Keyboard binding provides the key mappings.
    @Override
    public GridCell Move(int keyCode) {
        GridCell newCell = null;
        if (!_isGrappling) {
            if (_direction == PlayerDirection.Up) {
                if (keyCode == _keyBinding.Up) {
                    newCell = MoveUp();
                    _direction = PlayerDirection.Up;
                    IncrementSprite(_skin.UpSprites, false, false);
                } else if (keyCode == _keyBinding.Right) {
                    newCell = MoveRight();
                    _direction = PlayerDirection.Right;
                    IncrementSprite(_skin.RightSprites, true, false);
                } else if (keyCode == _keyBinding.Left) {
                    newCell = MoveLeft();
                    _direction = PlayerDirection.Left;
                    //IncrementSprite(_skin.LRSprites, true, true);
                    IncrementSprite(_skin.LeftSprites, true, false);
                } else if (keyCode == _keyBinding.Down) {
                    newCell = MoveDown();
                    _direction = PlayerDirection.Down;
                    IncrementSprite(_skin.DownSprites, true, false);
                }
            } else if (_direction == PlayerDirection.Left) {
                if (keyCode == _keyBinding.Left) {
                    newCell = MoveLeft();
                    _direction = PlayerDirection.Left;
                    //IncrementSprite(_skin.LRSprites, false, true);
                    IncrementSprite(_skin.LeftSprites, false, false);
                } else if (keyCode == _keyBinding.Up) {
                    newCell = MoveUp();
                    _direction = PlayerDirection.Up;
                    IncrementSprite(_skin.UpSprites, true, false);
                } else if (keyCode == _keyBinding.Down) {
                    newCell = MoveDown();
                    _direction = PlayerDirection.Down;
                    IncrementSprite(_skin.DownSprites, true, false);
                } else if (keyCode == _keyBinding.Right) {
                    newCell = MoveRight();
                    _direction = PlayerDirection.Right;
                    IncrementSprite(_skin.RightSprites, true, false);
                }
            } else if (_direction == PlayerDirection.Right) {
                if (keyCode == _keyBinding.Right) {
                    newCell = MoveRight();
                    _direction = PlayerDirection.Right;
                    IncrementSprite(_skin.RightSprites, false, false);
                } else if (keyCode == _keyBinding.Up) {
                    newCell = MoveUp();
                    _direction = PlayerDirection.Up;
                    IncrementSprite(_skin.UpSprites, true, false);
                } else if (keyCode == _keyBinding.Down) {
                    newCell = MoveDown();
                    _direction = PlayerDirection.Down;
                    IncrementSprite(_skin.DownSprites, true, false);
                } else if (keyCode == _keyBinding.Left) {
                    newCell = MoveLeft();
                    _direction = PlayerDirection.Left;
                    //IncrementSprite(_skin.LRSprites, true, true);
                    IncrementSprite(_skin.LeftSprites, true, false);
                }
            } else if (_direction == PlayerDirection.Down) {
                if (keyCode == _keyBinding.Down) {
                    newCell = MoveDown();
                    _direction = PlayerDirection.Down;
                    IncrementSprite(_skin.DownSprites, false, false);
                } else if (keyCode == _keyBinding.Right) {
                    newCell = MoveRight();
                    _direction = PlayerDirection.Right;
                    IncrementSprite(_skin.RightSprites, true, false);
                } else if (keyCode == _keyBinding.Left) {
                    newCell = MoveLeft();
                    _direction = PlayerDirection.Left;
                    //IncrementSprite(_skin.LRSprites, true, true);
                    IncrementSprite(_skin.LeftSprites, true, false);
                } else if (keyCode == _keyBinding.Up) {
                    newCell = MoveUp();
                    _direction = PlayerDirection.Up;
                    IncrementSprite(_skin.UpSprites, true, false);
                }
            }
        }
        return newCell;
    }

    // Move up. Reduce row.
    private GridCell MoveUp() {
        var newCell = new GridCell(_body.get(0).Row - 1, _body.get(0).Column);
        if (CanMoveTo(newCell, OccupiedCells)) {
            _body.set(0, newCell);
            return newCell;
        }
        else{
            return _body.get(0);
        }
    }

    // Move left. Reduce column.
    private GridCell MoveLeft(){
        var newCell = new GridCell(_body.get(0).Row, _body.get(0).Column - 1);
        if (CanMoveTo(newCell, OccupiedCells)) {
            _body.set(0, newCell);
            return newCell;
        }
        else{
            return _body.get(0);
        }
    }

    // Move right. Increase column.
    private GridCell MoveRight(){
        var newCell = new GridCell(_body.get(0).Row, _body.get(0).Column + 1);
        if (CanMoveTo(newCell, OccupiedCells)) {
            _body.set(0, newCell);
            return newCell;
        }
        else{
            return _body.get(0);
        }
    }

    // Move down. Increase row.
    private GridCell MoveDown(){
        var newCell = new GridCell(_body.get(0).Row + 1, _body.get(0).Column);
        if (CanMoveTo(newCell, OccupiedCells)) {
            _body.set(0, newCell);
            return newCell;
        }
        else{
            return _body.get(0);
        }
    }

    // Check if we can move to this cell.
    private boolean CanMoveTo(GridCell newCell, ArrayList<GridCell> occupiedCells) {
        var offsetYL = 4;
        var offsetYU = 0;
        var offsetXL = 3;
        var offsetXU = 1;
        var result = true;
        if (occupiedCells != null) {
            for (GridCell target : occupiedCells) {
                if ((target.Row - offsetYL <= newCell.Row && newCell.Row <= target.Row + offsetYU)
                        && (target.Column - offsetXL <= newCell.Column && newCell.Column <= target.Column + offsetXU)
                ) {
                    result = false;
                    break;
                }
            }
        }
        return result;
    }

    // Render the player.
    @Override
    public void Render(GameEngine engine) {
        engine.changeColor(Color.white);
        DrawName(engine, _body.get(0));
        DrawHealth(engine, _body.get(0));
        engine.drawImage(_image.Image,
                _image.Reflect? (_body.get(0).Column * _skin.CellWidth + GameImage.MinotaurWithAxe_WIDTH) : (_body.get(0).Column * _skin.CellWidth + 5),
                _body.get(0).Row * _skin.CellHeight + 5,
                (_image.Reflect? -1 : 1) * (GameImage.MinotaurWithAxe_WIDTH),
                GameImage.MinotaurWithAxe_HEIGHT);
    }

    @Override
    public void Update(Double dt) {
        StateMachine.Execute(dt, World, this);
    }

    // Check grapple collisions with enemies.
    public void CheckObjectCollision(GridCell currentCell) {
        for (IWorldObject object : World.GetObjects()) {
            if (object.WhoAmI() == WorldObjectType.Player || object.WhoAmI() == WorldObjectType.NPC) {
                if (!CanMoveTo(currentCell, new ArrayList<>(Arrays.asList(object.GetOccupiedCells())))) {
                    object.HandleDamage();
                }
            }
        }
    }

    // Get All cells occupied by the snake.
    @Override
    public GridCell[] GetOccupiedCells() {
        return _body.toArray(new GridCell[0]);
    }

    // Handles snake collision.
    @Override
    public IWorldObject HandleCollision(IWorldObject object) {
        IWorldObject toRemove = null;
        var type = object.WhoAmI();

        // If collided with another player.
        if (type == WorldObjectType.Player || object.WhoAmI() == WorldObjectType.NPC) {
            object.HandleDamage();
        }

        return toRemove;
    }

    // Returns object's type.
    @Override
    public WorldObjectType WhoAmI() {
        return WorldObjectType.GhostWizard;
    }

    // Get object's name.
    @Override
    public String GetName() {
        return _name;
    }

    @Override
    public void SetGridCell(GridCell cell) {
        _body.set(0, cell);
    }

    @Override
    public void HandleDamage() {
        //AudioRequests.add(new AudioRequest(WorldObjectType.Minotaur));
        _lives -= 1;
        // No more health. The player is removed from the game.
        if (_lives <= 0) {
            EliminationRequests.push(this);
            Minotaur.BossIsDead = true;
        }
    }

    // Draw player identifier.
    private void DrawName(GameEngine engine, GridCell cell){
        var offset = 0;
        engine.drawText(cell.Column * _skin.CellWidth, cell.Row * _skin.CellHeight + offset, _name, "Arial", 12);
    }

    // Draw health icons based on number of lives.
    private void DrawHealth(GameEngine engine, GridCell cell){
        var offsetV = -10;
        var offsetH = 35;
        for(int i = 0; i < _lives; i++){
            engine.drawImage(_skin.Health, cell.Column * _skin.CellWidth + i * 10, cell.Row * _skin.CellHeight, 10, 10);
        }
    }

    // Get next sprite image.
    private void IncrementSprite(Image[] sprites, boolean reset, boolean reflect) {
        _spriteIndex++;
        if (_spriteIndex == sprites.length || reset) {
            _spriteIndex = 0;
        }
        _image.Image = sprites[_spriteIndex];
        _image.Reflect = reflect;
    }

    public void FireProjectile() {
        var startX = _body.get(0).Column * _skin.CellWidth + GameImage.MinotaurWithAxe_WIDTH / 2;
        var startY = _body.get(0).Row * _skin.CellHeight + GameImage.MinotaurWithAxe_HEIGHT / 2;
        var radius = 5;
        var r = new Random();
        var ball = new Ball(java.util.UUID.randomUUID().toString(), radius, _skin.CellWidth, _skin.CellHeight, AudioRequests, AnimationRequests, EliminationRequests);
        ball.Position = new Vector2D(startX, startY);
        ball.Velocity = new Vector2D(r.nextDouble(500,1000), r.nextDouble(500, 1000));
        ball.Acceleration = new Vector2D(0, Ball.G);
        ball.Color = Color.RED;
        SpawnRequests.add(ball);

        /*
        double x = _body.get(0).Column * _skin.CellWidth + _skin.CellWidth / 2.0;
        double y = _body.get(0).Row * _skin.CellHeight + _skin.CellHeight / 2.0;

        // Determine the direction the body is facing
        PlayerDirection direction = _direction;

        // Adjust the x and y coordinates based on the direction
        switch (direction) {
            case Up:
                y -= _skin.CellHeight / 2.0;
                break;
            case Down:
                y += _skin.CellHeight / 2.0;
                break;
            case Left:
                x -= _skin.CellWidth / 2.0;
                break;
            case Right:
                x += _skin.CellWidth / 2.0;
                break;
        }

        // Create a projectile with an initial velocity
        double projectileVelocity = 5.0; // Adjust the velocity as needed
        double velocityX = 0.0;
        double velocityY = 0.0;

        switch (direction) {
            case Up:
                velocityY = -projectileVelocity;
                break;
            case Down:
                velocityY = projectileVelocity;
                break;
            case Left:
                velocityX = -projectileVelocity;
                break;
            case Right:
                velocityX = projectileVelocity;
                break;
        }

        //Projectile projectile = new Projectile(x, y, velocityX, velocityY);

        // Update and draw the projectile until it is off-screen
        //while (isOnScreen(projectile.getX(), projectile.getY())) {
            //projectile.update();
            // Draw the projectile
            //System.out.println("Fire");
            // engine.drawSolidCircle(projectile.getX(), projectile.getY(), 10);
        }
         */
    }
    }

