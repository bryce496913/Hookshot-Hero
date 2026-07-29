import java.util.ArrayList;
import java.util.HashMap;

public class SpeechService {
    public static final String MISSION_GUIDE_SARAH = "Warrior! Your mission is to help Ava escape the Dungeon. Ava will follow you along the way. Good luck!";
    public static final HashMap<SpeechType, String> Conversations;

    static {
        Conversations = new HashMap<>();
        Conversations.put(SpeechType.Happy, "Nice!!");
        Conversations.put(SpeechType.Health, "Yummy!!");
        Conversations.put(SpeechType.Danger, "Ouch!!");
        Conversations.put(SpeechType.Victory, "Take that!!");
        Conversations.put(SpeechType.NPCComment, "Lets go!");
        Conversations.put(SpeechType.Celebrate, "Victory!");
    }

    public static void Say(SpeechType type, ArrayList<AnimationRequest> requests, Player player) {
        String message = getConversation(type);
        var speech = new AnimationRequest(WorldObjectType.SpeechBubble, player.GetOccupiedCells()[0], 5);
        speech.Text = message;
        speech.Player = player;
        requests.add(speech);
    }

    public static void NPCSay(SpeechType type, ArrayList<AnimationRequest> requests, Player player) {
        String message = getConversation(type);
        var speech = new AnimationRequest(WorldObjectType.SpeechBubble, player.GetOccupiedCells()[0], 10);
        speech.Text = message;
        speech.Player = player;
        requests.add(speech);
    }

    public static void BGCSay(SpeechType type, ArrayList<AnimationRequest> requests, Player player) {
        String message = getConversation(type);

        var speech = new AnimationRequest(WorldObjectType.SpeechBubble, player.GetOccupiedCells()[0], 10);
        speech.Text = message;
        speech.Player = player;
        requests.add(speech);
    }

    private static String getConversation(SpeechType type) {
        return Conversations.getOrDefault(type, Conversations.get(SpeechType.NPCComment));
    }
}
