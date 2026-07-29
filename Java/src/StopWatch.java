import java.util.Date;
public class StopWatch {
    private Date _start;
    private long _total = 0;
    private boolean _isStop = false;

    public void Start(){
        _start = new Date();
        _isStop = false;
    }

    public void Stop(){
        var lapsed = new Date().getTime() - _start.getTime();
        _total += lapsed;
        _isStop = true;
    }

    public void Reset(){
        _total = 0;
        _start = new Date();
        _isStop = false;
    }

    public long GetTimeInSeconds(){
        if(!_isStop) {
            var lapsed = new Date().getTime() - _start.getTime();
            return (lapsed + _total) / 1000;
        }
        return _total / 1000;
    }
}
