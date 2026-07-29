import java.util.ArrayList;

/****************************************************************************************
 * Interface for game world builder.
 ****************************************************************************************/
public interface IWorldBuilder {
    IWorld Build(HookshotHeroesGameEngine engine, GameImage gameImage, GameAudio gameAudio, GameOptions options,
                 ILevel level, ArrayList<Player> players, ArrayList<Player> npcplayers);
}
