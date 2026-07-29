import java.util.ArrayList;
import java.util.HashMap;

public class SpeechService {
    public static Boolean EnableChatGPT = true;
    public static final String CHATGPT_HAPPY_PROMPT = "say a short sentence when you feel happy or getting rich";
    public static final String CHATGPT_DANGER_PROMPT = "say something when you stepped on a nail";
    public static final String CHATGPT_HEALTH_PROMPT = "say a short sentence when you eat yummy food or recovered health";
    public static final String CHATGPT_VICTORY_PROMPT = "say a short sentence when you defeat an enemy";
    public static final String CHATGPT_CELEBRATE_PROMPT = "say a short sentence when you and your friend are victorious";
    public static final String CHATGPT_NPC_COMMENT_PROMPT = "say a short sentence when fighting side by side with your friend";
    public static final String CHATGPT_NPC_JOKE_PROMPT = "say something funny";
    public static final String CHATGPT_NPC_WORRIED_PROMPT = "say a short sentence when you are fighting your way out of a dungeon with your friend";
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
        String message = "";
        if (type == SpeechType.Happy) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_HAPPY_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.Happy);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.Happy);
                }
            } else {
                message = Conversations.get(SpeechType.Happy);
            }
        } else if (type == SpeechType.Health) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_HEALTH_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.Health);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.Health);
                }
            } else {
                message = Conversations.get(SpeechType.Health);
            }
        } else if (type == SpeechType.Danger) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_DANGER_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.Danger);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.Danger);
                }
            } else {
                message = Conversations.get(SpeechType.Danger);
            }
        } else if (type == SpeechType.Victory) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_VICTORY_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.Victory);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.Victory);
                }
            } else {
                message = Conversations.get(SpeechType.Victory);
            }
        }


        var speech = new AnimationRequest(WorldObjectType.SpeechBubble, player.GetOccupiedCells()[0], 5);
        speech.Text = message;
        speech.Player = player;
        requests.add(speech);
    }

    public static void NPCSay(SpeechType type, ArrayList<AnimationRequest> requests, Player player) {
        String message = "";
        if (type == SpeechType.Happy) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_HAPPY_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.Happy);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.Happy);
                }
            } else {
                message = Conversations.get(SpeechType.Happy);
            }
        } else if (type == SpeechType.Health) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_HEALTH_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.Health);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.Health);
                }
            } else {
                message = Conversations.get(SpeechType.Health);
            }
        } else if (type == SpeechType.Danger) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_DANGER_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.Danger);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.Danger);
                }
            } else {
                message = Conversations.get(SpeechType.Danger);
            }
        } else if (type == SpeechType.Victory) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_VICTORY_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.Victory);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.Victory);
                }
            } else {
                message = Conversations.get(SpeechType.Victory);
            }
        } else if (type == SpeechType.NPCComment) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_NPC_COMMENT_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.NPCComment);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.NPCComment);
                }
            } else {
                message = Conversations.get(SpeechType.NPCComment);
            }
        } else if (type == SpeechType.NPCWorried) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_NPC_WORRIED_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.NPCComment);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.NPCComment);
                }
            } else {
                message = Conversations.get(SpeechType.NPCComment);
            }
        } else if (type == SpeechType.NPCJoke) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_NPC_JOKE_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.NPCComment);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.NPCComment);
                }
            } else {
                message = Conversations.get(SpeechType.NPCComment);
            }
        }



        var speech = new AnimationRequest(WorldObjectType.SpeechBubble, player.GetOccupiedCells()[0], 10);
        speech.Text = message;
        speech.Player = player;
        requests.add(speech);
    }

    public static void BGCSay(SpeechType type, ArrayList<AnimationRequest> requests, Player player) {
        String message = "";
        if (type == SpeechType.Celebrate) {
            if (EnableChatGPT) {
                try {
                    var response = ChatGPTConnector.SendRequestToChatGPT(CHATGPT_CELEBRATE_PROMPT);
                    message = ChatGPTConnector.ExtractGeneratedMessage(response);
                    if (!(message != null && !message.trim().isEmpty())){
                        message = Conversations.get(SpeechType.Celebrate);
                    }
                } catch (Exception ex) {
                    System.out.println("ChatGPT error: " + ex.getMessage());
                    message = Conversations.get(SpeechType.Celebrate);
                }
            } else {
                message = Conversations.get(SpeechType.Celebrate);
            }
        }

        var speech = new AnimationRequest(WorldObjectType.SpeechBubble, player.GetOccupiedCells()[0], 10);
        speech.Text = message;
        speech.Player = player;
        requests.add(speech);
    }
}
