/****************************************************************************************
 * Encapsulates an audio play request.
 ****************************************************************************************/
public class AudioRequest {
    public WorldObjectType Type;
    public AudioVoiceType VoiceType = AudioVoiceType.None;
    public AudioRequest(WorldObjectType type){
        Type = type;
    }
}
