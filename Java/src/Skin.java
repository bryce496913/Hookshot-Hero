import java.awt.*;

/****************************************************************************************
 * This class represents object skins.
 ****************************************************************************************/
public class Skin {
    public Image Head, Body, Health;
    public Image[] UpSprites, LRSprites, DownSprites, LeftSprites, RightSprites, StaticSprites;
    public int CellWidth, CellHeight;
    public Skin(Image body, int width, int height){
        Body = body;
        CellWidth = width;
        CellHeight = height;
    }
    public Skin(Image[] upSprites, Image[] lrSprites, Image[] downSprites, Image health, int width, int height){
        Health = health;
        CellWidth = width;
        CellHeight = height;
        UpSprites = upSprites;
        LRSprites = lrSprites;
        DownSprites = downSprites;
    }

    public Skin(Image[] upSprites, Image[] lSprites, Image[] rSprites, Image[] downSprites, Image health, int width, int height){
        Health = health;
        CellWidth = width;
        CellHeight = height;
        UpSprites = upSprites;
        LeftSprites = lSprites;
        RightSprites = rSprites;
        DownSprites = downSprites;
    }

    public Skin(Image[] staticSprites, int width, int height){
        CellWidth = width;
        CellHeight = height;
        StaticSprites = staticSprites;
    }
}
