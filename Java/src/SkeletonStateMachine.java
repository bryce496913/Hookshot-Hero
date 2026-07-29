public class SkeletonStateMachine extends NPCSimpleStateMachine implements IStateMachine {
    public SkeletonStateMachine() {
        super.PATROL_REACTION_TIME = 0.7;
        super.SEEK_REACTION_TIME = 0.5;
        super.SIGHT = Skeleton.SIGHT;
    }
}
