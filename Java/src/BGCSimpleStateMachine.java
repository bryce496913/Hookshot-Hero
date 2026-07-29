import java.awt.event.KeyEvent;
import java.util.ArrayList;
import java.util.Date;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

public class BGCSimpleStateMachine implements IStateMachine{
    private double _time = 0;
    private double _commentTime = 0;

    // Time of NPC reaction during patrol.
    public double PATROL_REACTION_TIME = 0.5;
    // Time of NPC reaction during pursuit.
    public double SEEK_REACTION_TIME = 0.15;
    // Time it takes to make the next comment
    public double COMMENT_REACTION_TIME = 15;
    // Sight of NPC
    public int SIGHT = 15;
    // Waiting range of NPC.
    public int WAIT_RANGE = 3;
    // NPC current state.
    public NPCStates State = NPCStates.Patrol;

    // Run the State Machine.
    // This implementation only have two states.
    public GridCell Execute(double dt, IWorld world, IWorldObject npc) {
        GridCell nextCell = null;
        if (State == NPCStates.Patrol) {
            if (_time > PATROL_REACTION_TIME) {
                _time = 0;
                Random r = new Random();
                var nextMove = r.nextInt(1, 5);
                if (nextMove == 1) {
                    nextCell = npc.Move(KeyEvent.VK_UP);
                } else if (nextMove == 2) {
                    nextCell = npc.Move(KeyEvent.VK_RIGHT);
                } else if (nextMove == 3) {
                    nextCell = npc.Move(KeyEvent.VK_DOWN);
                } else if (nextMove == 4) {
                    nextCell = npc.Move(KeyEvent.VK_LEFT);
                }
                npc.CheckObjectCollision(nextCell);
                // Check players range
                CheckPlayersRange(world, npc, SIGHT);
            } else {
                _time += dt;
            }
        } else if (State == NPCStates.Seek) {
            if (_time > SEEK_REACTION_TIME) {
                _time = 0;
                var player = GetClosestPlayer(world, npc);
                nextCell = DoOptimalMovement(world, npc, player);
                if (nextCell != null) {
                    npc.CheckObjectCollision(nextCell);
                    var closestPlayer = GetClosestPlayer(world, npc);
                    var dist = GetDistance(closestPlayer.GetOccupiedCells()[0], npc.GetOccupiedCells()[0]);
                    if (dist <= 5){
                        State = NPCStates.Wait;
                    }
                }
            } else {
                _time += dt;
            }
        } else if (State == NPCStates.Wait) {
            if (_time > SEEK_REACTION_TIME) {
                _time = 0;
                // Check players range
                CheckPlayersRange(world, npc, SIGHT);
            } else {
                _time += dt;
            }
        }

        // Make some comments
        if (_commentTime > COMMENT_REACTION_TIME){
            _commentTime = 0;
            Random r = new Random();
            var say = r.nextInt(0, 2);
            if (say == 1) {
                if (State == NPCStates.Patrol) {
                    CompletableFuture.runAsync(() -> {
                        SpeechService.BGCSay(SpeechType.Celebrate, ((Player) npc).AnimationRequests, (Player) npc);
                    });
                } else if (State == NPCStates.Seek) {
                    CompletableFuture.runAsync(() -> {
                        SpeechService.BGCSay(SpeechType.Celebrate, ((Player) npc).AnimationRequests, (Player) npc);
                    });
                } else {
                    CompletableFuture.runAsync(() -> {
                        SpeechService.BGCSay(SpeechType.Celebrate, ((Player) npc).AnimationRequests, (Player) npc);
                    });
                }
            }
        } else{
            _commentTime += dt;
        }
        return nextCell;
    }



    // Check if we should change state.
    // If a player is in range then start chasing.
    public void CheckPlayersRange(IWorld world, IWorldObject npc, int sight){
        double min = Double.MAX_VALUE;
        for (IWorldObject object : world.GetObjects()) {
            if ((object.WhoAmI() == WorldObjectType.Player || object.WhoAmI() == WorldObjectType.NPC)
                    && npc.GetName() != object.GetName()) {
                var dist = GetDistance(object.GetOccupiedCells()[0], npc.GetOccupiedCells()[0]);
                if (dist < min) {
                    min = dist;
                }
            }
        }
        if (min <= sight && min > WAIT_RANGE) {
            State = NPCStates.Seek;
        }
        else {
            State = NPCStates.Patrol;
        }
    }

    // Get the closest player.
    public IWorldObject GetClosestPlayer(IWorld world, IWorldObject npc){
        double min = Double.MAX_VALUE;
        IWorldObject player = null;
        for (IWorldObject object : world.GetObjects()) {
            if ((object.WhoAmI() == WorldObjectType.Player || object.WhoAmI() == WorldObjectType.NPC)
                    && npc.GetName() != object.GetName()) {
                var dist = GetDistance(object.GetOccupiedCells()[0], npc.GetOccupiedCells()[0]);
                if (dist < min) {
                    min = dist;
                    player = object;
                }
            }
        }
        return player;
    }

    // Perform the optimal movement that gets to the player the quickest.
    public GridCell DoOptimalMovement(IWorld world, IWorldObject npc, IWorldObject player){
        GridCell nextCell = null;
        double min = Double.MAX_VALUE;
        var minIdx = 0;

        var currentCell = npc.GetOccupiedCells()[0];
        var option1 = new GridCell(currentCell.Row, currentCell.Column - 1);
        var option2 = new GridCell(currentCell.Row + 1, currentCell.Column);
        var option3 = new GridCell(currentCell.Row, currentCell.Column + 1);
        var option4 = new GridCell(currentCell.Row - 1, currentCell.Column);
        var options = new ArrayList<GridCell>();
        options.add(option1);
        options.add(option2);
        options.add(option3);
        options.add(option4);

        for (int i = 0; i < options.size(); i++){
            var dist = GetDistance(player.GetOccupiedCells()[0], options.get(i));
            if (dist < min) {
                min = dist;
                minIdx = i;
            }
        }

        var currentGrid = npc.GetOccupiedCells()[0];
        if (minIdx == 0) {
            nextCell = npc.Move(KeyEvent.VK_LEFT);
        } else if (minIdx == 1) {
            nextCell = npc.Move(KeyEvent.VK_DOWN);
        } else if (minIdx == 2) {
            nextCell = npc.Move(KeyEvent.VK_RIGHT);
        } else if (minIdx == 3) {
            nextCell = npc.Move(KeyEvent.VK_UP);
        }

        if (nextCell != null && nextCell.Row == currentGrid.Row && nextCell.Column == currentGrid.Column){
            nextCell = npc.Move(KeyEvent.VK_PERIOD);
        }

        return nextCell;
    }

    public double GetDistance(GridCell cell1, GridCell cell2){
        var diffX = cell1.Column - cell2.Column;
        var diffY = cell1.Row - cell2.Row;
        var dist = Math.sqrt(diffX * diffX + diffY * diffY);
        return dist;
    }
}
