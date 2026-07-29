import java.util.ArrayList;

public interface ILevel {
    void RenderLevel();
    ILevel GetNextLevel();
    ILevel GetPreviousLevel();
    GridCell[] GetTopStartingPos();
    GridCell[] GetBottomStartingPos();
    GridCell[] GetExitGrid();
    NextLevelInfo[] GetNextLevelInfo();
    GridCell GetEntryGrid();
    LevelStartPos GetStartPos();
    void SetStartPos(LevelStartPos pos);
    ArrayList<GridCell> GetWallCells();
    ArrayList<GridCell> GetLavaCells();
    ArrayList<GridCell> GetOccupiedCells();
    void SetLevelRendered(boolean flag);
    String GetLevelName();
    ArrayList<Chest> GetChests();
    void ApplyLevelMusic(GameAudio gameAudio);
    boolean CanExit(IWorld world);
    void AddEmitter(int x, int y);
    void Update(double dt);
    void RenderEmitters();
    ArrayList<GridCell> GetUnoccupiedCells();
}
