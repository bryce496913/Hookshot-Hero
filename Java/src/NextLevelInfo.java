public class NextLevelInfo {
    public final ILevel NextLevel;
    public final GridCell Exit;
    public NextLevelInfo(GridCell exit, ILevel nextLevel){
        Exit = exit;
        NextLevel = nextLevel;
    }
}
