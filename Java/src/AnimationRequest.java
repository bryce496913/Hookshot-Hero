import java.awt.*;
import java.util.Comparator;
import java.util.Date;

/****************************************************************************************
 * Class for storing animation requests.
 ****************************************************************************************/
public class AnimationRequest {
    public GridCell Cell;
    public double time = 0;
    // Type of animation is linked to object type and its sprites.
    public WorldObjectType Type;
    // Time to play the animation.
    public double SecondsToPlay;
    // Text / speech.
    public String Text;
    // The player.
    public Player Player;
    // The chest.
    public Chest Chest;
    // The guide.
    public Guide Guide;
    // Notification Type.
    public NotificationType NotificationType;
    // Creation timestamp.
    public final Date CreatedTime;
    // Color of speech bubble.
    public final Color Color;
    public AnimationRequest(WorldObjectType type, GridCell cell, double seconds){
        Type = type;
        Cell = cell;
        SecondsToPlay = seconds;
        CreatedTime = new Date();
        Color = ColorUtils.GetRandomColor();
    }
}
