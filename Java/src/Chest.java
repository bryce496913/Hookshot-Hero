public class Chest {
    private final GridCell _cell;
    public boolean IsOpened = false;
    public final boolean HasMessage;
    public final boolean IsTalkingChest;
    public final String Message;
    public final int CHEST_LIVES = 2;
    public final int CHEST_SCORES = 100;
    public Chest(GridCell cell, boolean hasMessage, String message, boolean isTalkingChest){
        _cell = cell;
        HasMessage = hasMessage;
        Message = message;
        IsTalkingChest = isTalkingChest;
    }
    public GridCell GetCell(){
        return _cell;
    }
}
