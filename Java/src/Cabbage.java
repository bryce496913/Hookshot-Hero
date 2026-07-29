public class Cabbage implements IWorldObject {
    private final String _name;
    private GridCell _cell;
    private final Skin _skin;
    public Cabbage(String name, GridCell cell, Skin skin){
        _name = name;
        _cell = cell;
        _skin = skin;
    }
    @Override
    public GridCell Move(int keyCode) {
        return null;
    }

    @Override
    public void Render(GameEngine engine) {
        engine.drawImage(_skin.Body, _cell.Column * _skin.CellWidth, _cell.Row * _skin.CellHeight, 20, 20);
    }

    @Override
    public void Update(Double dt) {

    }

    @Override
    public GridCell[] GetOccupiedCells() {
        return new GridCell[] { _cell };
    }

    @Override
    public IWorldObject HandleCollision(IWorldObject object) {
        return null;
    }

    @Override
    public WorldObjectType WhoAmI() {
        return WorldObjectType.Cabbage;
    }

    @Override
    public String GetName() {
        return _name;
    }

    @Override
    public void SetGridCell(GridCell cell) {
        _cell = cell;
    }

    @Override
    public void HandleDamage() {

    }

    @Override
    public void CheckObjectCollision(GridCell currentCell) {

    }
}
