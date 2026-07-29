/****************************************************************************************
 * Interface for objects that exits in the game.
 ****************************************************************************************/
public interface IWorldObject {
    GridCell Move(int keyCode);
    void Render(GameEngine engine);
    void Update(Double dt);
    GridCell[] GetOccupiedCells();
    IWorldObject HandleCollision(IWorldObject object);
    WorldObjectType WhoAmI();
    String GetName();
    void SetGridCell(GridCell cell);
    void HandleDamage();
    void CheckObjectCollision(GridCell currentCell);
}
