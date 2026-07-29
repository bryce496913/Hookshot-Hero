/****************************************************************************************
 * DTO for storing collision related info.
 ****************************************************************************************/
public class CollisionCheckInfo {
    // Collision location.
    public GridCell Cell;
    // Source object.
    public IWorldObject Source;
    // Target object.
    public IWorldObject Target;
    // Object to remove after suffering from collision damage.
    public IWorldObject Remove;

    public CollisionCheckInfo(GridCell cell, IWorldObject source){
        Cell = cell;
        Source = source;
    }
    public CollisionCheckInfo(GridCell cell, IWorldObject source, IWorldObject target){
        this(cell, source);
        Target = target;
    }
    public CollisionCheckInfo(GridCell cell, IWorldObject source, IWorldObject target, IWorldObject remove){
        this(cell, source, target);
        Remove = remove;
    }
}
