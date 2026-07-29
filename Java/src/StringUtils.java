import java.util.ArrayList;

public class StringUtils {
    public static ArrayList<String> GetLines(String text, int wordsPerLine){
        String[] words = text.trim().split("\\s+");
        ArrayList<String> lines = new ArrayList<>();
        String line = "";
        int counter = 0;
        for(int i = 0; i < words.length; i++){
            if (line == "") {
                line += words[i];
            } else{
                line += " " + words[i];
            }
            counter++;
            if (counter == wordsPerLine || i == words.length - 1) {
                lines.add(line);
                line = "";
                counter = 0;
            }
        }
        return lines;
    }
}
