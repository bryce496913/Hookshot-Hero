import java.awt.*;

public class NPCSprites {
    public Image[] UpSprites, DownSprites, LeftSprites, RightSprites;
    public NPCSprites(Image[] upSprites, Image[] lSprites, Image[] rSprites, Image[] downSprites){
        UpSprites = upSprites;
        LeftSprites = lSprites;
        RightSprites = rSprites;
        DownSprites = downSprites;
    }
}
