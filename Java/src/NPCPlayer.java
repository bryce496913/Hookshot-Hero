import java.awt.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedList;
import java.util.concurrent.CompletableFuture;

public class NPCPlayer extends Player implements IWorldObject{
    // Player health.
    public static final int MAX_LIFE = 5;
    public static final int GRAPPLE_ADVANCE = 1;
    public static final int GRAPPLE_LENGTH = 19;
    public static final int GRAPPLE_CHAIN_GAP = 10;
    public static final int GRAPPLE_CHAIN_RADIUS = 2;
    public static final int GRAPPLE_CHAIN_WIDTH = 1;
    public static final int GRAPPLE_RADIUS = 5;
    public static final int PLAYER_LEVEL_SCORE = 100;
    public static final int PLAYER_COIN_SCORE = 10;
    public static final int PLAYER_HIT_SCORE = 10;
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
    private GridCell _grappleCell = null;
    // Number of lives
    private int _lives = 3;
    private int _spriteIndex = 0;
    private ObjectImage _image = null;
    private boolean _isGrappling = false;
    public LinkedList<AudioRequest> AudioRequests;
    public LinkedList<IWorldObject> EliminationRequests;
    public ArrayList<AnimationRequest> AnimationRequests;
    public IWorld World;
    public IStateMachine StateMachine;

    public NPCPlayer(String name, GridCell startCell, Skin skin, KeyBinding keyBinding,
                     ArrayList<GridCell> wallCells, ArrayList<GridCell> lavaCells, ArrayList<GridCell> occupiedCells,
                     LinkedList<AudioRequest> audioRequests, LinkedList<IWorldObject> eliminationRequests, ArrayList<AnimationRequest> animationRequests,
                     IWorld world) {
        super(name, startCell, skin, keyBinding, wallCells, lavaCells, occupiedCells, audioRequests, eliminationRequests, animationRequests, world);
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
        AnimationRequests = animationRequests;
        World = world;
        StateMachine = new FollowerStateMachine();
    }

    // Move the player.
    // Use the direction of the player to decide the movement after key press.
    // Keyboard binding provides the key mappings.
    @Override
    public GridCell Move(int keyCode) {
        if (keyCode == _keyBinding.Grapple) {
            _isGrappling = true;
            _grappleCell = new GridCell(_body.get(0).Row, _body.get(0).Column);
            //AudioRequests.add(new AudioRequest(WorldObjectType.Grapple));
        }
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
        if(_isGrappling) {
            engine.changeColor(Color.BLACK);
            engine.drawLine(_body.get(0).Column * _skin.CellWidth + 35, _body.get(0).Row * _skin.CellHeight + 35,
                    _grappleCell.Column * _skin.CellWidth + 35, _grappleCell.Row * _skin.CellHeight + 35, GRAPPLE_CHAIN_WIDTH);

            engine.drawCircle(_grappleCell.Column * _skin.CellWidth + 35, _grappleCell.Row * _skin.CellHeight + 35, GRAPPLE_RADIUS);

            var chainh = Math.abs(_grappleCell.Column * _skin.CellWidth - _body.get(0).Column * _skin.CellWidth);
            var chainv = Math.abs(_grappleCell.Row * _skin.CellHeight - _body.get(0).Row * _skin.CellHeight);
            var numberOfChains = Math.max(chainh, chainv) / GRAPPLE_CHAIN_GAP;

            for (int i = 0; i < numberOfChains; i++){
                if (_direction == PlayerDirection.Up) {
                    engine.drawCircle(_body.get(0).Column * _skin.CellWidth + 35, _body.get(0).Row * _skin.CellHeight + 35 - i * GRAPPLE_CHAIN_GAP, GRAPPLE_CHAIN_RADIUS);
                } else if (_direction == PlayerDirection.Down) {
                    engine.drawCircle(_body.get(0).Column * _skin.CellWidth + 35, _body.get(0).Row * _skin.CellHeight + 35 + i * GRAPPLE_CHAIN_GAP, GRAPPLE_CHAIN_RADIUS);
                }
                if (_direction == PlayerDirection.Left) {
                    engine.drawCircle(_body.get(0).Column * _skin.CellWidth + 35 - i * GRAPPLE_CHAIN_GAP, _body.get(0).Row * _skin.CellHeight + 35, GRAPPLE_CHAIN_RADIUS);
                }
                if (_direction == PlayerDirection.Right) {
                    engine.drawCircle(_body.get(0).Column * _skin.CellWidth + 35 + i * GRAPPLE_CHAIN_GAP, _body.get(0).Row * _skin.CellHeight + 35, GRAPPLE_CHAIN_RADIUS);
                }
            }
        }
        engine.changeColor(Color.white);
        DrawName(engine, _body.get(0));
        DrawHealth(engine, _body.get(0));
        engine.drawImage(_image.Image,
                _image.Reflect? (_body.get(0).Column * _skin.CellWidth + GameImage.LIDIA_WIDTH) : (_body.get(0).Column * _skin.CellWidth + 5),
                _body.get(0).Row * _skin.CellHeight + 5,
                (_image.Reflect? -1 : 1) * (GameImage.LIDIA_WIDTH + 10),
                GameImage.LIDIA_HEIGHT - 20);
    }

    @Override
    public void Update(Double dt) {
        var playerPos = _body.get(0);
        if (_isGrappling) {
            if (_direction == PlayerDirection.Up) {
                if (!CanMoveTo(new GridCell( _grappleCell.Row - GRAPPLE_ADVANCE, playerPos.Column), WallCells)
                        && CanMoveTo(new GridCell( playerPos.Row - GRAPPLE_ADVANCE, playerPos.Column), WallCells)) {
                    playerPos.Row -= GRAPPLE_ADVANCE;
                    if (playerPos.Row == _grappleCell.Row) {
                        _isGrappling = false;
                    }
                } else if (_grappleCell.Row != playerPos.Row - GRAPPLE_LENGTH &&
                        CanMoveTo(new GridCell( playerPos.Row - GRAPPLE_ADVANCE, playerPos.Column), WallCells)) {
                    _grappleCell.Row -= GRAPPLE_ADVANCE;
                    CheckObjectCollision(_grappleCell);
                } else {
                    _isGrappling = false;
                }
            }
            if (_direction == PlayerDirection.Down) {
                if (!CanMoveTo(new GridCell( _grappleCell.Row + GRAPPLE_ADVANCE, playerPos.Column), WallCells)
                        && CanMoveTo(new GridCell( playerPos.Row + GRAPPLE_ADVANCE, playerPos.Column), WallCells)) {
                    playerPos.Row += GRAPPLE_ADVANCE;
                    if (playerPos.Row  == _grappleCell.Row) {
                        _isGrappling = false;
                    }
                } else if (_grappleCell.Row != playerPos.Row + GRAPPLE_LENGTH &&
                        CanMoveTo(new GridCell( playerPos.Row + GRAPPLE_ADVANCE, playerPos.Column), WallCells)) {
                    _grappleCell.Row += GRAPPLE_ADVANCE;
                    CheckObjectCollision(_grappleCell);
                } else {
                    _isGrappling = false;
                }
            }
            if (_direction == PlayerDirection.Left) {
                if (!CanMoveTo(new GridCell(playerPos.Row, _grappleCell.Column - GRAPPLE_ADVANCE), WallCells)
                        && CanMoveTo(new GridCell(playerPos.Row, playerPos.Column - GRAPPLE_ADVANCE), WallCells)) {
                    playerPos.Column -= GRAPPLE_ADVANCE;
                    if (playerPos.Column == _grappleCell.Column) {
                        _isGrappling = false;
                    }
                } else if (_grappleCell.Column != playerPos.Column - GRAPPLE_LENGTH
                        && CanMoveTo(new GridCell(playerPos.Row, playerPos.Column - GRAPPLE_ADVANCE), WallCells)) {
                    _grappleCell.Column -= GRAPPLE_ADVANCE;
                    CheckObjectCollision(_grappleCell);
                } else {
                    _isGrappling = false;
                }
            }
            if (_direction == PlayerDirection.Right) {
                if (!CanMoveTo(new GridCell(playerPos.Row, _grappleCell.Column + GRAPPLE_ADVANCE), WallCells)
                        && CanMoveTo(new GridCell(playerPos.Row, playerPos.Column + GRAPPLE_ADVANCE), WallCells)) {
                    playerPos.Column += GRAPPLE_ADVANCE;
                    if (playerPos.Column == _grappleCell.Column) {
                        _isGrappling = false;
                    }
                } else if (_grappleCell.Column != playerPos.Column + GRAPPLE_LENGTH
                        && CanMoveTo(new GridCell(playerPos.Row, playerPos.Column + GRAPPLE_ADVANCE), WallCells)) {
                    _grappleCell.Column += GRAPPLE_ADVANCE;
                    CheckObjectCollision(_grappleCell);
                } else {
                    _isGrappling = false;
                }
            }
        }
        else {
            if (!CanMoveTo(playerPos, LavaCells)) {
                _lives -= 1;
                AudioRequests.add(new AudioRequest(WorldObjectType.Ball));
                DrawNotification(playerPos, NotificationType.Health, -1);
                if (_lives <= 0) {
                    EliminationRequests.push(this);
                }
            }
        }

        StateMachine.Execute(dt, World, this);
    }

    // Check grapple collisions with enemies.
    public void CheckObjectCollision(GridCell currentCell) {
        for (IWorldObject object : World.GetObjects()) {
            if (object.WhoAmI() == WorldObjectType.Mine) {
                if (!CanMoveTo(currentCell, new ArrayList<>(Arrays.asList(object.GetOccupiedCells())))) {
                    HandleDamage();
                    AnimationRequests.add(new AnimationRequest(WorldObjectType.Mine, object.GetOccupiedCells()[0], 10));
                    AudioRequests.add(new AudioRequest(WorldObjectType.Mine));
                    EliminationRequests.push(object);
                    HandleVoice(WorldObjectType.Mine);
                }
            }
            if (object.WhoAmI() == WorldObjectType.Coin) {
                if (!CanMoveTo(currentCell, new ArrayList<>(Arrays.asList(object.GetOccupiedCells())))) {
                    CompletableFuture.runAsync(() -> {
                        SpeechService.NPCSay(SpeechType.Happy, AnimationRequests, this);
                    });
                    Score += PLAYER_COIN_SCORE;
                    DrawNotification(currentCell, NotificationType.Score, PLAYER_COIN_SCORE);
                    AudioRequests.add(new AudioRequest(WorldObjectType.Coin));
                    EliminationRequests.push(object);
                    HandleVoice(WorldObjectType.Cabbage);
                }
            }
            if (object.WhoAmI() == WorldObjectType.Cabbage) {
                if (!CanMoveTo(currentCell, new ArrayList<>(Arrays.asList(object.GetOccupiedCells())))) {
                    CompletableFuture.runAsync(() -> {
                        SpeechService.NPCSay(SpeechType.Health, AnimationRequests, this);
                    });
                    if (_lives < MAX_LIFE){
                        _lives++;
                    }
                    AudioRequests.add(new AudioRequest(WorldObjectType.Cabbage));
                    EliminationRequests.push(object);
                    DrawNotification(currentCell, NotificationType.Health, 1);
                    HandleVoice(WorldObjectType.Cabbage);
                }
            }
            if (object.WhoAmI() == WorldObjectType.Minotaur || object.WhoAmI() == WorldObjectType.Skeleton
                    || object.WhoAmI() == WorldObjectType.GhostWizard || object.WhoAmI() == WorldObjectType.FlyingTerror) {
                if (!CanMoveTo(currentCell, new ArrayList<>(Arrays.asList(object.GetOccupiedCells())))) {
                    HandleDamage();
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
        // If collided with an apple. Remove apple and increase length of snake.
        if (type == WorldObjectType.Apple) {
            if(_lives < MAX_LIFE) {
                _lives += 1;
                DrawNotification(object.GetOccupiedCells()[0], NotificationType.Health, 1);
                HandleVoice(WorldObjectType.Cabbage);
            }
            toRemove = object;
        }
        // If collided with another player (or itself).
        else if (type == WorldObjectType.Player) {
            //toRemove = this;
        }
        // Collided with mine or bouncing ball, reduce health by 1.
        else if (type == WorldObjectType.Mine || type == WorldObjectType.Ball) {
            _lives -= 1;
            CompletableFuture.runAsync(() -> {
                SpeechService.NPCSay(SpeechType.Danger, AnimationRequests, this);
            });
            DrawNotification(object.GetOccupiedCells()[0], NotificationType.Health, -1);
            HandleVoice(WorldObjectType.Mine);
            // No more health. The player is removed from the game.
            if (_lives <= 0) {
                toRemove = this;
            } else {
                if (object.WhoAmI() != WorldObjectType.Ball) {
                    toRemove = object;
                }
            }
        } else if (type == WorldObjectType.Broccoli || type == WorldObjectType.Cabbage) {
            CompletableFuture.runAsync(() -> {
                SpeechService.NPCSay(SpeechType.Health, AnimationRequests, this);
            });
            DrawNotification(object.GetOccupiedCells()[0], NotificationType.Health, 1);
            if(_lives < MAX_LIFE) {
                _lives += 1;
                HandleVoice(WorldObjectType.Cabbage);
            }
            toRemove = object;
        } else if (type == WorldObjectType.Coin) {
            CompletableFuture.runAsync(() -> {
                SpeechService.NPCSay(SpeechType.Happy, AnimationRequests, this);
            });
            DrawNotification(object.GetOccupiedCells()[0], NotificationType.Score, PLAYER_COIN_SCORE);
            HandleVoice(WorldObjectType.Cabbage);
            Score += PLAYER_COIN_SCORE;
            toRemove = object;
        }
        return toRemove;
    }

    // Returns object's type.
    @Override
    public WorldObjectType WhoAmI() {
        return WorldObjectType.NPC;
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
        _lives -= 1;
        CompletableFuture.runAsync(() -> {
            SpeechService.NPCSay(SpeechType.Danger, AnimationRequests, this);
        });
        DrawNotification(_body.get(0), NotificationType.Health, -1);
        HandleVoice(WorldObjectType.Mine);
        // No more health. The player is removed from the game.
        if (_lives <= 0) {
            EliminationRequests.push(this);
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
            engine.drawImage(_skin.Health, cell.Column * _skin.CellWidth + i * 10 + offsetH, cell.Row * _skin.CellHeight + offsetV, 10, 10);
        }
    }

    // Draw notifications to the left.
    private void DrawNotification(GridCell cell, NotificationType type, int score){
        var scoreNotification = new AnimationRequest(WorldObjectType.Notification, cell, 5);
        scoreNotification.NotificationType = type;
        scoreNotification.Text = (score > 0)? ("+" + score) : "" + score;
        scoreNotification.Player = this;
        AnimationRequests.add(scoreNotification);
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
}
