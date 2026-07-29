import java.awt.*;

public class Coin implements IWorldObject{
    private final String _name;
    private GridCell _cell;
    private final Skin _skin;
    private int _idx = 0;

    public Coin(String name, GridCell cell, Skin skin){
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
        var offset = 10;
        if (_idx / offset >= _skin.StaticSprites.length) {
            _idx = 0;
        }
        engine.drawImage(_skin.StaticSprites[_idx / offset], _cell.Column * _skin.CellWidth + 5, _cell.Row * _skin.CellHeight + 5);
        if (!((HookshotHeroesGameEngine) engine).IsPause()) {
            _idx++;
        }
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
        return WorldObjectType.Coin;
    }

    @Override
    public String GetName() {
        return _name;
    }

    @Override
    public void SetGridCell(GridCell cell){
        _cell = cell;
    }

    @Override
    public void HandleDamage() {

    }

    @Override
    public void CheckObjectCollision(GridCell currentCell) {

    }
}
