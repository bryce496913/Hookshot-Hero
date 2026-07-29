import javax.swing.*;
import java.awt.*;
import java.awt.event.KeyEvent;
import java.awt.geom.GeneralPath;
import java.util.*;

/****************************************************************************************
 * The World class encapsulate the game world
 ****************************************************************************************/
public class World implements IWorld {
    public final int CELL_WIDTH = 10, CELL_HEIGHT = 10;
    public int GridRows, GridColumns;

    // Reference to the game.
    public HookshotHeroesGameEngine Engine;
    public GameImage GameImage;
    public GameAudio GameAudio;
    public GameOptions GameOptions;

    // List of objects in the game.
    public ArrayList<IWorldObject> Objects;

    // A list of animations to play.
    public ArrayList<AnimationRequest> AnimationRequests;

    // Elimination list.
    public LinkedList<IWorldObject> EliminationRequests;

    // A FIFO queue for playing audios.
    public LinkedList<AudioRequest> AudioRequests;

    // Spawn new objects.
    public LinkedList<IWorldObject> SpawnRequests;

    // Environment Levels.
    public ILevel CurrentLevel;

    private int _idx = 0;

    public boolean IsEndGame = false;

    // List to store eliminated players.
    public ArrayList<Player> EliminatedPlayers;

    public World(int width, int height, HookshotHeroesGameEngine engine, GameImage gameImage, GameAudio gameAudio, GameOptions options, ILevel level){
        Engine = engine;
        GameImage = gameImage;
        GameAudio = gameAudio;
        GameOptions = options;

        // Level world grid
        // The map is divided into cells of 10px by 10px.
        // Player can move 1 cell at a time.
        GridRows = height / CELL_HEIGHT;
        GridColumns = width / CELL_WIDTH;
        AnimationRequests = new ArrayList<>();
        AudioRequests = new LinkedList<>();
        EliminationRequests = new LinkedList<>();
        SpawnRequests = new LinkedList<>();
        EliminatedPlayers = new ArrayList<>();

        CurrentLevel = level;
    }

    public IWorldObject[] GetObjects() {
        return Objects.toArray(new IWorldObject[Objects.size()]);
    }

    public ArrayList<IWorldObject> GetObjectArrayList() {
        return Objects;
    }

    // Set the objects in this gaming world.
    public void SetObjects(IWorldObject[] objects){
        Objects = new ArrayList<>();
        Collections.addAll(Objects, objects);
    }

    public void SetObjects(ArrayList<IWorldObject> objects){
        Objects = objects;
    }

    public void RenderLevel() {
        CurrentLevel.RenderLevel();
        CurrentLevel.RenderEmitters();
        CurrentLevel.SetLevelRendered(true);
    }

    public void RenderObjects(){
        for (IWorldObject object : Objects) {
            object.Render(Engine);
        }
    }

    @Override
    public void UpdateObjects(double dt) {
        for (IWorldObject object : Objects) {
            object.Update(dt);
        }
        CurrentLevel.Update(dt);
        if (EliminationRequests.size() > 0) {
            var player = EliminationRequests.pop();
            HandleElimination(player);
        }
        if (SpawnRequests.size() > 0) {
            var object = SpawnRequests.pop();
            HandleAddition(object);
        }
    }

    public void HandleKeyEvents(KeyEvent event){
        var toCheck = MoveObjects(event);
        CheckCollision(toCheck);
    }

    // Advances movable objects by 1 grid at a time.
    // The new grid cell to move to will be checked for any collisions.
    private ArrayList<CollisionCheckInfo> MoveObjects(KeyEvent event) {
        var toCheck = new ArrayList<CollisionCheckInfo>();
        // Advance each player in the world and gather the collision info.
        for (IWorldObject object : Objects) {
            if (object.WhoAmI() == WorldObjectType.Player) {
                var newCell = object.Move(event.getKeyCode());
                if (newCell != null) {
                    AudioRequests.add(new AudioRequest(WorldObjectType.Player));
                    toCheck.add(new CollisionCheckInfo(newCell, object));
                }
            }
        }
        return toCheck;
    }

    // Check for collisions from a list of new grid cells objects are moving into.
    private void CheckCollision(ArrayList<CollisionCheckInfo> toCheck){
        // Go through each collected collision info and check if collision happened.
        for (CollisionCheckInfo collisionCheckInfo : toCheck) {
            // Check exit grid
            var exits = CurrentLevel.GetNextLevelInfo();
            for (int i = 0; i < exits.length; i++) {
                if (CheckGrid(collisionCheckInfo.Cell, exits[i].Exit)){
                    if (CurrentLevel.CanExit(this)) {
                        ((Player) collisionCheckInfo.Source).Score += Player.PLAYER_LEVEL_SCORE;
                        var nextLevel = exits[i].NextLevel;
                        if (nextLevel != null) {
                            Engine.InitializeLevel(Engine.GameOptions, nextLevel, GetPlayers(), GetNPCPlayers());
                        } else {
                            Engine.PauseEngine();
                            // Trigger end game screen.
                            Minotaur.BossIsDead = false;
                            LevelSeven.FromLevelSeven = false;
                            IsEndGame = true;
                        }
                        return;
                    }
                }
            }
            // Check entry grid
            if (CheckGrid(collisionCheckInfo.Cell, CurrentLevel.GetEntryGrid())){
                var prevLevel = CurrentLevel.GetPreviousLevel();
                if (prevLevel != null){
                    prevLevel.SetStartPos(LevelStartPos.Top);
                    Engine.InitializeLevel(Engine.GameOptions, prevLevel, GetPlayers(), GetNPCPlayers());
                }
                return;
            }
            // Check going over the boundaries.
            var toRemove = CheckBoundaryCollision(collisionCheckInfo.Cell, collisionCheckInfo.Source);
            if (toRemove == null) {
                // Check object / object collision.
                var info = CheckObjectCollision(collisionCheckInfo.Cell, collisionCheckInfo.Source);
                if (info != null) {
                    toRemove = info.Remove;
                    // Special case here as both collided objects need to be removed.
                    if (info.Remove != null && info.Remove.WhoAmI() == WorldObjectType.Player &&
                            info.Target.WhoAmI() == WorldObjectType.Mine) {
                        HandleCollision(info.Target, info.Source);
                    }
                }
            }
            // Remove the collided object.
            HandleCollision(toRemove, collisionCheckInfo.Source);
        }
    }

    // Given a new grid cell, check if there are any objects in the cell.
    // If collision detected, decide if the object needs to be removed from the game world.
    private CollisionCheckInfo CheckObjectCollision(GridCell newCell, IWorldObject object){
        CollisionCheckInfo info = null;
        IWorldObject collidedObject = null;
        for (IWorldObject iWorldObject : Objects) {
            // Get a list of cells occupied.
            var cells = iWorldObject.GetOccupiedCells();
            if (object.GetName().equals(iWorldObject.GetName()) && cells.length == 1) {
                continue;
            }
            for (int j = 0; j < cells.length; j++) {
                // Player boundary box
                if (newCell.Row <= cells[j].Row && cells[j].Row <= (newCell.Row + 3)
                        && newCell.Column <= cells[j].Column && cells[j].Column <= (newCell.Column + 3)) {
                    // Call each objects specific handle collision function.
                    collidedObject = object.HandleCollision(iWorldObject);
                    info = new CollisionCheckInfo(newCell, object, iWorldObject, collidedObject);
                    break;
                }
            }
            if (collidedObject != null) {
                break;
            }
        }
        return info;
    }

    private boolean CheckGrid(GridCell newCell, GridCell target){
        var offsetY = 3;
        var offsetX = 3;
        var result = false;
        if ((target.Row - offsetY <= newCell.Row && newCell.Row <= target.Row + offsetY)
        && (target.Column - offsetX <= newCell.Column && newCell.Column <= target.Column + offsetX)
        ){
            result = true;
        }
        return result;
    }

    // Check if the object has moved beyond the grid boundaries.
    private IWorldObject CheckBoundaryCollision(GridCell newCell, IWorldObject object){
        IWorldObject collidedObject = null;
        var offset = 2;
        if (newCell.Row < 0 || newCell.Row > GridRows - offset || newCell.Column < 0 || newCell.Column > GridColumns - offset){
            collidedObject = object;
        }
        return collidedObject;
    }

    // Handle the aftermath of the collisions.
    // Prompt message popup if game over.
    // Decide if we need to play sound effects after collision.
    public void HandleCollision(IWorldObject collidedObject, IWorldObject src){
        var offset = 5;
        if (collidedObject != null) {
            var type = collidedObject.WhoAmI();
            if (type == WorldObjectType.Player) {
                if (((Player)collidedObject).GetHealth() <= 0) {
                    HandleElimination(collidedObject);
                }
            }
            else if (type == WorldObjectType.Apple || type == WorldObjectType.Broccoli || type == WorldObjectType.Cabbage) {
                // Play eat apple sound effects.
                AudioRequests.add(new AudioRequest(WorldObjectType.Apple));
                if (src != null)
                    ((Player)src).HandleVoice(WorldObjectType.Cabbage);
                // Spawn new random apple.
                //collidedObject.SetGridCell(GridCell.GetRandomCell(offset, GridRows - offset, offset, GridColumns - offset));
                RemoveObject(collidedObject);
            }
            else if (type == WorldObjectType.Mine) {
                // Play explosion sound effects.
                AnimationRequests.add(new AnimationRequest(type, collidedObject.GetOccupiedCells()[0], 10));
                AudioRequests.add(new AudioRequest(WorldObjectType.Mine));
                if (src != null)
                    ((Player)src).HandleVoice(WorldObjectType.Mine);
                // Spawn new random mine.
                //collidedObject.SetGridCell(GridCell.GetRandomCell(offset, GridRows - offset, offset, GridColumns - offset));
                RemoveObject(collidedObject);
            }
            else if (type == WorldObjectType.Coin) {
                // Play explosion sound effects.
                AudioRequests.add(new AudioRequest(WorldObjectType.Coin));
                RemoveObject(collidedObject);
            }
        }
    }

    public void HandleElimination(IWorldObject player) {
        if (player.WhoAmI() == WorldObjectType.Player || player.WhoAmI() == WorldObjectType.NPC) {
            // Player game over.
            Engine.PauseEngine();
            JOptionPane.showMessageDialog(Engine.mFrame, player.GetName() + " eliminated!");
            EliminatedPlayers.add((Player)player);
            RemoveObject(player);
            // Game over - no players left.
            if (GetPlayerCount() == 0 || GameOptions.MissionMode && GetNPCPlayerCount() == 0) {
                Minotaur.BossIsDead = false;
                LevelSeven.FromLevelSeven = false;
                IsEndGame = true;
            } else {
                Engine.ResumeEngine();
            }
        }
        if (player.WhoAmI() == WorldObjectType.Mine || player.WhoAmI() == WorldObjectType.Cabbage
                || player.WhoAmI() == WorldObjectType.Coin || player.WhoAmI() == WorldObjectType.Skeleton 
                || player.WhoAmI() == WorldObjectType.Minotaur || player.WhoAmI() == WorldObjectType.GhostWizard
                || player.WhoAmI() == WorldObjectType.FlyingTerror || player.WhoAmI() == WorldObjectType.NPC
                || player.WhoAmI() == WorldObjectType.Ball) {
            RemoveObject(player);
        }
    }

    public void HandleAddition(IWorldObject object) {
        Objects.add(object);
    }

    @Override
    public ILevel GetLevel() {
        return CurrentLevel;
    }

    // Remove object from the gaming world.
    @Override
    public void RemoveObject(IWorldObject toRemove) {
        if (toRemove != null) {
            Objects.removeIf(iWorldObject -> iWorldObject.GetName().equals(toRemove.GetName()));
        }
    }

    @Override
    public boolean IsEndGame() {
        return IsEndGame;
    }

    @Override
    public void PrintResults(int width, int height, long time) {
        Engine.changeBackgroundColor(Color.darkGray);
        Engine.clearBackground(width, height);

        Engine.changeColor(Color.ORANGE);
        // Check if we win or lose.
        if (GetPlayerCount() == 0 || GameOptions.MissionMode && GetNPCPlayerCount() == 0){
            Engine.drawText(200, 100, "GAME OVER", "Arial", 32);

        } else {
            Engine.drawText(200, 100, "VICTORY", "Arial", 32);
        }
        Engine.drawText(200, 150, "Time: " + time + " Seconds", "Arial", 12);
        var list = new ArrayList<Player>();
        list.addAll(GetPlayers());
        list.addAll(EliminatedPlayers);
        list.addAll(GetNPCPlayers());
        // Sort by scores in descending order.
        Collections.sort(list, Comparators.GetPlayerComparator());
        for (int i = 0; i < list.size(); i++) {
            Engine.drawText(200, 200 + i * 50, list.get(i).GetName() + "'s Score: " + list.get(i).Score, "Arial", 12);
        }
        Engine.changeColor(Color.YELLOW);
        Engine.drawText(200, 350, "Press Space to Restart", "Arial", 12);
    }

    @Override
    public void HandleRestart() {
        IsEndGame = false;
        Engine.ResumeEngine();
        Engine.InitializeWorld(GameOptions);
    }

    // Remove played animations.
    private void RemoveAnimationRequests() {
        Iterator<AnimationRequest> itr = AnimationRequests.iterator();
        while (itr.hasNext()) {
            var request = (AnimationRequest)itr.next();
            // If we have finished playing most of the track.
            if (request.time > request.SecondsToPlay * 2 / 3)
                itr.remove();
        }
    }

    // Get the number of players.
    public int GetPlayerCount(){
        var count = 0;
        for (IWorldObject object : Objects) {
            if (object.WhoAmI() == WorldObjectType.Player) {
                count++;
            }
        }
        return count;
    }

    // Get the number of npc players.
    public int GetNPCPlayerCount(){
        var count = 0;
        for (IWorldObject object : Objects) {
            if (object.WhoAmI() == WorldObjectType.NPC) {
                count++;
            }
        }
        return count;
    }

    // Get the players.
    public ArrayList<Player> GetPlayers() {
        var players = new ArrayList<Player>();
        for (IWorldObject object : Objects) {
            if (object.WhoAmI() == WorldObjectType.Player) {
                players.add((Player) object);
            }
        }
        return players;
    }

    // Get the npc players.
    public ArrayList<Player> GetNPCPlayers() {
        var players = new ArrayList<Player>();
        for (IWorldObject object : Objects) {
            if (object.WhoAmI() == WorldObjectType.NPC) {
                players.add((Player) object);
            }
        }
        return players;
    }

    // Update each animation request on the amount of time played.
    public void UpdateAnimationRequests(double dt){
        try {
            for (AnimationRequest request : AnimationRequests) {
                request.time += dt;
            }
            UpdateBalls(dt);
        }
        catch (Exception ex) {
            System.out.println(ex.getMessage());
        }
    }

    // Play the animation based on object type.
    public void PlayAnimation() {
        try {
            ArrayList<AnimationRequest> lidiaList = new ArrayList<>();
            ArrayList<AnimationRequest> shuraList = new ArrayList<>();
            ArrayList<AnimationRequest> lidiaNotifications = new ArrayList<>();
            ArrayList<AnimationRequest> shuraNotifications = new ArrayList<>();
            ArrayList<AnimationRequest> avaList = new ArrayList<>();
            ArrayList<AnimationRequest> avaNotifications = new ArrayList<>();

            for (AnimationRequest request : AnimationRequests) {
                // Only support explosion animation.
                if (request.Type == WorldObjectType.Mine) {
                    var idx = Engine.GetFrameIndex(request.time, request.SecondsToPlay, GameImage.ExplosionSprites.length);
                    Engine.drawImage(GameImage.ExplosionSprites[idx], request.Cell.Column * CELL_HEIGHT - 10, request.Cell.Row * CELL_WIDTH - 30, 50, 50);
                }
                if (request.Type == WorldObjectType.SpeechBubble) {
                    if (request.Player != null && request.Player.GetName() == CharacterNames.LIDIA) {
                        lidiaList.add(request);
                    } else if (request.Player != null && request.Player.GetName() == CharacterNames.SHURA) {
                        shuraList.add(request);
                    } else if (request.Player != null && request.Player.GetName() == CharacterNames.AVA) {
                        avaList.add(request);
                    }
                    else {
                        DrawBGCSpeechBubble(Engine,  request.Player.GetOccupiedCells()[0], request.Text, request.Color);
                    }
                }
                if (request.Type == WorldObjectType.Notification) {
                    if (request.Player != null && request.Player.GetName() == CharacterNames.LIDIA) {
                        lidiaNotifications.add(request);
                    } else if (request.Player != null && request.Player.GetName() == CharacterNames.SHURA) {
                        shuraNotifications.add(request);
                    } else if (request.Player != null && request.Player.GetName() == CharacterNames.AVA) {
                        avaNotifications.add(request);
                    }
                }
                if (request.Type == WorldObjectType.ChestBubble) {
                    DrawChestBubble(Engine, request.Chest);
                }
                if (request.Type == WorldObjectType.GuideBubble) {
                    DrawGuideBubble(Engine, request.Guide);
                }
            }
            // Sort in descending order.
            Collections.sort(lidiaList, Comparators.GetAnimationRequestComparator());
            Collections.sort(shuraList, Comparators.GetAnimationRequestComparator());
            Collections.sort(avaList, Comparators.GetAnimationRequestComparator());
            Collections.sort(lidiaNotifications, Comparators.GetAnimationRequestComparator());
            Collections.sort(shuraNotifications, Comparators.GetAnimationRequestComparator());
            Collections.sort(avaNotifications, Comparators.GetAnimationRequestComparator());

            // Show speech bubbles in sequence.
            DrawSpeechBubblesFromList(lidiaList);
            DrawSpeechBubblesFromList(shuraList);
            DrawSpeechBubblesFromList(avaList);

            // Show notification in sequence.
            DrawNotificationsFromList(lidiaNotifications);
            DrawNotificationsFromList(shuraNotifications);
            DrawNotificationsFromList(avaNotifications);

            // Clean up
            RemoveAnimationRequests();
        } catch (Exception ex) {

        }
    }

    // Play audio effects.
    public void PlayAudio(){
        if (AudioRequests.size() > 0) {
            var request = AudioRequests.pop();
            if (request.Type == WorldObjectType.Mine) {
                // Explosion sound.
                Engine.playAudio(GameAudio.ExplosionAudio, GameOptions.SoundEffectsVolume);
            }
            else if (request.Type == WorldObjectType.Apple) {
                // Crunch sound.
                Engine.playAudio(GameAudio.CrunchAudio, GameOptions.SoundEffectsVolume);
            }
            else if (request.Type == WorldObjectType.Player) {
                Engine.playAudio(GameAudio.WalkAudio, GameOptions.MovementVolume);
            }
            else if (request.Type == WorldObjectType.Ball) {
                Engine.playAudio(GameAudio.HitAudio, GameOptions.SoundEffectsVolume);
            }
            else if (request.Type == WorldObjectType.Grapple) {
                Engine.playAudio(GameAudio.WhipAudio, GameOptions.SoundEffectsVolume);
            }
            else if (request.Type == WorldObjectType.Coin) {
                Engine.playAudio(GameAudio.CoinAudio, GameOptions.MovementVolume);
            }
            else if (request.Type == WorldObjectType.Minotaur){
                Engine.playAudio(GameAudio.MonsterDamageAudio, GameOptions.SoundEffectsVolume);
            }
            else if (request.Type == WorldObjectType.Skeleton || request.Type == WorldObjectType.GhostWizard){
                Engine.playAudio(GameAudio.SkeletonAudio, 0);
            }
            else if (request.Type == WorldObjectType.FlyingTerror) {
                Engine.playAudio(GameAudio.FTAudio, GameOptions.SoundEffectsVolume);
            }

            if (request.VoiceType == AudioVoiceType.LidiaHealed) {
                Engine.playAudio(GameAudio.LidiaHealedAudio, -10);
            }
            if (request.VoiceType == AudioVoiceType.ShuraHealed) {
                Engine.playAudio(GameAudio.ShuraHealedAudio, -10);
            }
            if (request.VoiceType == AudioVoiceType.AvaHealed) {
                Engine.playAudio(GameAudio.AvaHealedAudio, -10);
            }
            if (request.VoiceType == AudioVoiceType.LidiaDamaged) {
                Engine.playAudio(GameAudio.LidiaDamagedAudio, -10);
            }
            if (request.VoiceType == AudioVoiceType.ShuraDamaged) {
                Engine.playAudio(GameAudio.ShuraDamagedAudio, -10);
            }
            if (request.VoiceType == AudioVoiceType.AvaDamaged) {
                Engine.playAudio(GameAudio.AvaDamagedAudio, -10);
            }
            if (request.VoiceType == AudioVoiceType.LidiaAttack) {
                Engine.playAudio(GameAudio.LidiaAttackAudio, -10);
            }
            if (request.VoiceType == AudioVoiceType.ShuraAttack) {
                Engine.playAudio(GameAudio.ShuraAttackAudio, -10);
            }
        }
    }

    public void DrawSpeechBubblesFromList(ArrayList<AnimationRequest> requests){
        for (int i = 0; i < requests.size(); i++) {
            var grid = new GridCell(requests.get(i).Player.GetOccupiedCells()[0].Row + 5 * i, requests.get(i).Player.GetOccupiedCells()[0].Column);
            DrawBGCSpeechBubble(Engine,  grid, requests.get(i).Text, requests.get(i).Color);
        }
    }

    public void DrawNotificationsFromList(ArrayList<AnimationRequest> requests) {
        for (int i = 0; i < requests.size(); i++) {
            var grid = new GridCell(requests.get(i).Player.GetOccupiedCells()[0].Row + 2 * i, requests.get(i).Player.GetOccupiedCells()[0].Column);
            DrawNotification(Engine, grid, requests.get(i).NotificationType, requests.get(i).Text);
        }
    }

    public void DrawSpeechBubble(GameEngine engine, GridCell cell, String text){
        var offsetX = 50;
        var offsetY = 0;
        engine.saveCurrentTransform();
        var graphics2D = engine.mGraphics;
        graphics2D.translate(cell.Column * CELL_WIDTH + offsetX, cell.Row * CELL_HEIGHT + offsetY);
        RenderingHints qualityHints = new RenderingHints(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        qualityHints.put(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        graphics2D.setRenderingHints(qualityHints);
        graphics2D.setPaint(new Color(80, 150, 180));
        // Get lines from text.
        var lines = StringUtils.GetLines(text, 5);
        int width = (lines.size() == 1)? 5 * text.length() + 10 : 135;
        int height = 25 + 10 * (lines.size() - 1);
        GeneralPath path = new GeneralPath();
        path.moveTo(5, 10);
        path.curveTo(5, 10, 7, 5, 0, 0);
        path.curveTo(0, 0, 12, 0, 12, 5);
        path.curveTo(12, 5, 12, 0, 20, 0);
        path.lineTo(width - 10, 0);
        path.curveTo(width - 10, 0, width, 0, width, 10);
        path.lineTo(width, height - 10);
        path.curveTo(width, height - 10, width, height, width - 10, height);
        path.lineTo(15, height);
        path.curveTo(15, height, 5, height, 5, height - 10);
        path.lineTo(5, 15);
        path.closePath();
        graphics2D.fill(path);
        engine.changeColor(Color.white);

        for(int i = 0; i < lines.size(); i++){
            engine.drawText(10, 15 + i*10, lines.get(i), "Arial", 10);
        }

        engine.restoreLastTransform();
    }

    public void DrawBGCSpeechBubble(GameEngine engine, GridCell cell, String text, Color color){
        var offsetX = 50;
        var offsetY = 0;
        engine.saveCurrentTransform();
        var graphics2D = engine.mGraphics;
        graphics2D.translate(cell.Column * CELL_WIDTH + offsetX, cell.Row * CELL_HEIGHT + offsetY);
        RenderingHints qualityHints = new RenderingHints(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        qualityHints.put(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        graphics2D.setRenderingHints(qualityHints);
        graphics2D.setPaint(color);
        // Get lines from text.
        var lines = StringUtils.GetLines(text, 5);
        int width = (lines.size() == 1)? 5 * text.length() + 10 : 135;
        int height = 25 + 10 * (lines.size() - 1);
        GeneralPath path = new GeneralPath();
        path.moveTo(5, 10);
        path.curveTo(5, 10, 7, 5, 0, 0);
        path.curveTo(0, 0, 12, 0, 12, 5);
        path.curveTo(12, 5, 12, 0, 20, 0);
        path.lineTo(width - 10, 0);
        path.curveTo(width - 10, 0, width, 0, width, 10);
        path.lineTo(width, height - 10);
        path.curveTo(width, height - 10, width, height, width - 10, height);
        path.lineTo(15, height);
        path.curveTo(15, height, 5, height, 5, height - 10);
        path.lineTo(5, 15);
        path.closePath();
        graphics2D.fill(path);
        engine.changeColor(ColorUtils.GetContrastColor(color));

        for(int i = 0; i < lines.size(); i++){
            engine.drawText(10, 15 + i*10, lines.get(i), "Arial", 10);
        }

        engine.restoreLastTransform();
        engine.changeColor(Color.WHITE);
    }

    public void DrawChestBubble(GameEngine engine, Chest chest){
        var offsetX = 35;
        var offsetY = 10;
        engine.saveCurrentTransform();
        var graphics2D = engine.mGraphics;
        graphics2D.translate(chest.GetCell().Column * CELL_WIDTH + offsetX, chest.GetCell().Row * CELL_HEIGHT + offsetY);
        RenderingHints qualityHints = new RenderingHints(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        qualityHints.put(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        graphics2D.setRenderingHints(qualityHints);
        graphics2D.setPaint(Color.darkGray);
        // Get lines from text.
        var lines = StringUtils.GetLines(chest.Message, 5);
        int width = (lines.size() == 1)? 5 * chest.Message.length() + 30 : 200;
        int height = 25 + 10 * (lines.size() - 1);
        GeneralPath path = new GeneralPath();
        path.moveTo(5, 10);
        path.curveTo(5, 10, 7, 5, 0, 0);
        path.curveTo(0, 0, 12, 0, 12, 5);
        path.curveTo(12, 5, 12, 0, 20, 0);
        path.lineTo(width - 10, 0);
        path.curveTo(width - 10, 0, width, 0, width, 10);
        path.lineTo(width, height - 10);
        path.curveTo(width, height - 10, width, height, width - 10, height);
        path.lineTo(15, height);
        path.curveTo(15, height, 5, height, 5, height - 10);
        path.lineTo(5, 15);
        path.closePath();
        graphics2D.fill(path);
        engine.changeColor(Color.white);

        for(int i = 0; i < lines.size(); i++){
            engine.drawText(10, 15 + i*10, lines.get(i), "Arial", 12);
        }

        engine.restoreLastTransform();

        if (chest.IsTalkingChest) {
            var offset = 100;
            if (_idx / offset >= GameImage.SpecialChestSprites.length) {
                _idx = 0;
            }
            engine.drawImage(GameImage.SpecialChestSprites[_idx / offset], chest.GetCell().Column * CELL_WIDTH, chest.GetCell().Row * CELL_HEIGHT);
            if (!((HookshotHeroesGameEngine) engine).IsPause()) {
                _idx++;
            }
        }
    }

    public void DrawGuideBubble(GameEngine engine, Guide guide){
        var offsetX = 35;
        var offsetY = 10;
        engine.saveCurrentTransform();
        var graphics2D = engine.mGraphics;
        graphics2D.translate(guide.GetOccupiedCells()[0].Column * CELL_WIDTH + offsetX, guide.GetOccupiedCells()[0].Row * CELL_HEIGHT + offsetY);
        RenderingHints qualityHints = new RenderingHints(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        qualityHints.put(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        graphics2D.setRenderingHints(qualityHints);
        graphics2D.setPaint(Color.BLUE);
        // Get lines from text.
        var lines = StringUtils.GetLines(guide.Message, 5);
        int width = (lines.size() == 1)? 5 * guide.Message.length() + 30 : 200;
        int height = 25 + 10 * (lines.size() - 1);
        GeneralPath path = new GeneralPath();
        path.moveTo(5, 10);
        path.curveTo(5, 10, 7, 5, 0, 0);
        path.curveTo(0, 0, 12, 0, 12, 5);
        path.curveTo(12, 5, 12, 0, 20, 0);
        path.lineTo(width - 10, 0);
        path.curveTo(width - 10, 0, width, 0, width, 10);
        path.lineTo(width, height - 10);
        path.curveTo(width, height - 10, width, height, width - 10, height);
        path.lineTo(15, height);
        path.curveTo(15, height, 5, height, 5, height - 10);
        path.lineTo(5, 15);
        path.closePath();
        graphics2D.fill(path);
        engine.changeColor(Color.white);

        for(int i = 0; i < lines.size(); i++){
            engine.drawText(10, 15 + i*10, lines.get(i), "Arial", 12);
        }

        engine.restoreLastTransform();
    }

    public void DrawNotification(GameEngine engine, GridCell cell, NotificationType type, String text){
        var offsetX = -30;
        var offsetY = 0;
        if (type == NotificationType.Score) {
            engine.changeColor(Color.GREEN);
            engine.drawText(cell.Column * CELL_WIDTH + offsetX, cell.Row * CELL_HEIGHT + offsetY, text, "Arial", 12);
            engine.changeColor(Color.WHITE);
        } else if (type == NotificationType.Health) {
            engine.changeColor(Color.RED);
            engine.drawText(cell.Column * CELL_WIDTH + offsetX, cell.Row * CELL_HEIGHT + offsetY, text, "Arial", 12);
            engine.drawImage(GameImage.Health, cell.Column * CELL_WIDTH + offsetX + 15, cell.Row * CELL_HEIGHT - 9, 10, 10);
            engine.changeColor(Color.white);
        }
    }

    // Update the balls.
    public void UpdateBalls(double dt) {
        for(int i = 0; i < Objects.size(); i++) {
            var object = Objects.get(i);
            if (object.WhoAmI() == WorldObjectType.Ball) {
                var ball = (Ball) object;
                Ball.UpdateBall(ball, dt, CELL_HEIGHT * GridColumns, CELL_WIDTH * GridRows);
                for (int j = i + 1; j < Objects.size(); j++) {
                    var object2 = Objects.get(j);
                    if (object2.WhoAmI() == WorldObjectType.Ball) {
                        var ball2 = (Ball) object2;
                        if (Ball.CheckCollision(ball, ball2)) {
                            var tempX = ball.Velocity.X;
                            var tempY = ball.Velocity.Y;
                            ball.Velocity.X = ball2.Velocity.X;
                            ball.Velocity.Y = ball2.Velocity.Y;
                            ball2.Velocity.X = tempX;
                            ball2.Velocity.Y = tempY;
                        }
                    }
                }
                var result = Ball.CheckCollision(ball, this);
                if (result) {
                    ball.Velocity.X *= -1;
                    ball.Velocity.Y *= -1;
                    AudioRequests.add(new AudioRequest(WorldObjectType.Ball));
                }
            }
        }
    }
}
