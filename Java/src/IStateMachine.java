public interface IStateMachine {
    GridCell Execute(double dt, IWorld world, IWorldObject npc);
    void CheckPlayersRange(IWorld world, IWorldObject npc, int sight);
    IWorldObject GetClosestPlayer(IWorld world, IWorldObject npc);
    GridCell DoOptimalMovement(IWorld world, IWorldObject npc, IWorldObject player);
}
