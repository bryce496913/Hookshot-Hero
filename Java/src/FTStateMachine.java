public class FTStateMachine extends NPCSimpleStateMachine implements IStateMachine{
    public FTStateMachine(){
        super.PATROL_REACTION_TIME = 0.3;
        super.SEEK_REACTION_TIME = 0.3;
        super.SIGHT = FlyingTerror.SIGHT;
    }
}
