import java.awt.event.KeyEvent;
import java.util.ArrayList;

/****************************************************************************************
 * Interface for game worlds
 ****************************************************************************************/
public interface IWorld {
    IWorldObject[] GetObjects();
    ArrayList<IWorldObject> GetObjectArrayList();
    void SetObjects(IWorldObject[] objects);
    void SetObjects(ArrayList<IWorldObject> objects);
    void RenderLevel();
    void RenderObjects();
    void UpdateObjects(double dt);
    void HandleKeyEvents(KeyEvent event);
    int GetPlayerCount();
    void UpdateAnimationRequests(double dt);
    void PlayAnimation();
    void PlayAudio();
    void HandleCollision(IWorldObject collidedObject, IWorldObject src);
    ILevel GetLevel();
    ArrayList<Player> GetPlayers();
    void RemoveObject(IWorldObject toRemove);
    boolean IsEndGame();
    void PrintResults(int width, int height, long time);
    void HandleRestart();
}
