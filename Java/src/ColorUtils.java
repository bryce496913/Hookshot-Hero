import java.awt.*;
import java.util.Random;

public class ColorUtils {
    public static Color GetRandomColor(){
        var r = new Random();
        float red = r.nextFloat();
        float green = r.nextFloat();
        float blue = r.nextFloat();
        return new Color(red, green, blue);
    }

    public static Color GetContrastColor(Color color){
        // https://stackoverflow.com/questions/3942878/how-to-decide-font-color-in-white-or-black-depending-on-background-color/3943023#3943023
        return (color.getRed() * 0.299 + color.getGreen() * 0.587 + color.getBlue() * 0.114) > 150
                ? Color.BLACK
                : Color.WHITE;
    }
}
