import java.awt.event.KeyEvent;
import java.util.ArrayList;
import java.util.Random;

/****************************************************************************************
 * This class is a simple implementation of a NPC State Machine.
 ****************************************************************************************/
public class NPCSimpleStateMachine implements IStateMachine {
    private double _time = 0;
    private double _projectileTime = 0;

    // Time of NPC reaction during patrol.
    public double PATROL_REACTION_TIME = 0.5;
    // Time of NPC reaction during pursuit.
    public double SEEK_REACTION_TIME = 0.15;
    // Time to fire successive projectile shots.
    public double FIRING_TIME = 3;
    // Sight of NPC
    public int SIGHT = 20;
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
                }
            } else {
                _time += dt;
            }
        }

        if ((npc instanceof GhostWizard) && State == NPCStates.Seek && _projectileTime > FIRING_TIME) {
            _projectileTime = 0;
            ((GhostWizard) npc).FireProjectile();
        } else{
            _projectileTime += dt;
        }

        // Check players range
        CheckPlayersRange(world, npc, SIGHT);
        return nextCell;
    }



    // Check if we should change state.
    // If a player is in range then start chasing.
    public void CheckPlayersRange(IWorld world, IWorldObject npc, int sight){
        double min = Double.MAX_VALUE;
        for (IWorldObject object : world.GetObjects()) {
            if ((object.WhoAmI() == WorldObjectType.Player || object.WhoAmI() == WorldObjectType.NPC)
                    && npc.GetName() != object.GetName()) {
                var diffX = object.GetOccupiedCells()[0].Column - npc.GetOccupiedCells()[0].Column;
                var diffY = object.GetOccupiedCells()[0].Row - npc.GetOccupiedCells()[0].Row;
                var dist = Math.sqrt(diffX * diffX + diffY * diffY);
                if (dist < min) {
                    min = dist;
                }
            }
        }
        if (min <= sight) {
            State = NPCStates.Seek;
        } else {
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
                var diffX = object.GetOccupiedCells()[0].Column - npc.GetOccupiedCells()[0].Column;
                var diffY = object.GetOccupiedCells()[0].Row - npc.GetOccupiedCells()[0].Row;
                var dist = Math.sqrt(diffX * diffX + diffY * diffY);
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
            var diffX = player.GetOccupiedCells()[0].Column - options.get(i).Column;
            var diffY = player.GetOccupiedCells()[0].Row - options.get(i).Row;
            var dist = Math.sqrt(diffX * diffX + diffY * diffY);
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


}
