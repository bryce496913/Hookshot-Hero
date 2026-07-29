import java.util.Comparator;

public class Comparators {
    public static Comparator<AnimationRequest> GetAnimationRequestComparator(){
        return new Comparator<AnimationRequest>() {
            public int compare(AnimationRequest a1, AnimationRequest a2){
                if(a1.CreatedTime.getTime() == a2.CreatedTime.getTime())
                    return 0;
                return a1.CreatedTime.getTime() < a2.CreatedTime.getTime() ? 1 : -1;
            }
        };
    }

    public static Comparator<Player> GetPlayerComparator(){
        return new Comparator<Player>() {
            public int compare(Player p1, Player p2){
                if(p1.Score == p2.Score)
                    return 0;
                return p1.Score < p2.Score ? 1 : -1;
            }
        };
    }
}
