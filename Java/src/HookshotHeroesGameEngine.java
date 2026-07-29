import javax.imageio.ImageIO;
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;
import javax.swing.*;
import java.awt.*;
import java.awt.event.KeyEvent;
import java.io.BufferedInputStream;
import java.io.IOException;
import java.util.ArrayList;

/***********************************************
 * =============================================
 * HookshotHeroesEngine
 * The main entry point of the HookshotHeroes game.
 */
public class HookshotHeroesGameEngine extends GameEngine {

    private final int _width = 600, _height = 650, _fps = 120;
    private final GameImage _gameImage;
    private final GameAudio _gameAudio;
    private IWorld _world;
    private Boolean _pause = false;
    private final JMenuBar _menuBar;

    private StopWatch _stopWatch;
    private boolean _IsInitialized = false;

    public GameOptions GameOptions;

    public HookshotHeroesGameEngine(GameOptions options){
        // Create Game Image to handle all the sprite images.
        _gameImage = new GameImage(this);
        // Create Game Audio to handle all the sound clips.
        _gameAudio = new GameAudio(this);
        // Load default game options.
        GameOptions = options;
        GameOptions.Width = _width;
        GameOptions.Height = _height;

        // Build the default menu bar.
        var _menuBarBuilder = new DefaultMenuBarBuilder();
        _menuBar = _menuBarBuilder.BuildMenuBar(this);

        _stopWatch = new StopWatch();
    }

    // Initialize the game world based on game options.
    // Game options can be loaded from disk.
    public void InitializeWorld(GameOptions options){
        if(options.SinglePlayerMode){
            _world = new SinglePlayerWorldBuilder().Build(this, _gameImage, _gameAudio, options, new LevelOne(this, _gameImage, options), null, null);
        }
        else {
            _world = new DoublePlayerWorldBuilder().Build(this, _gameImage, _gameAudio, options, new LevelOne(this, _gameImage, options), null, null);
        }
        _stopWatch.Reset();
    }

    // Initialize the game world based on level.
    public void InitializeLevel(GameOptions options, ILevel level, ArrayList<Player> players, ArrayList<Player> npcplayers){
        if(options.SinglePlayerMode){
            _world = new SinglePlayerWorldBuilder().Build(this, _gameImage, _gameAudio, options, level, players, npcplayers);
        }
        else {
            _world = new DoublePlayerWorldBuilder().Build(this, _gameImage, _gameAudio, options, level, players, npcplayers);
        }
    }

    @Override
    public void init(){
        setupWindow(_width, _height);
        mFrame.setTitle("Hookshot Heroes");
        mFrame.setResizable(false);
        mFrame.setJMenuBar(_menuBar);
        // Start playing theme song.
        ToggleMusic();
    }

    public void close() {
        mFrame.dispose();
    }

    @Override
    public void update(double dt) {
        if (!_pause && !_world.IsEndGame()){
            // Handle animations and sprites.
            _world.UpdateObjects(dt);
            _world.UpdateAnimationRequests(dt);
        }
    }

    @Override
    public void paintComponent() {
        if (!_IsInitialized) {
            // Create the game world.
            InitializeWorld(GameOptions);
            _IsInitialized = true;
        }
        if (!_world.IsEndGame()) {
            changeBackgroundColor(Color.darkGray);
            clearBackground(_width, _height);

            // Render objects, play animations or audios.
            _world.RenderLevel();
            _world.RenderObjects();
            _world.PlayAnimation();
            _world.PlayAudio();

            drawText(10, 615, _world.GetLevel().GetLevelName() + " Time: " + _stopWatch.GetTimeInSeconds(), "Arial", 12);
            var players = _world.GetPlayers();
            for (int i = 0; i < players.size(); i++) {
                drawText(350 + i * 120, 615, players.get(i).GetName() + "'s score: " + players.get(i).Score, "Arial", 12);
            }

            if (_pause) {
                drawText(200, 150, "PAUSED", "Arial", 50);
                drawText(200, 250, "Press P to continue", "Arial", 22);
            }
        }
        else{
            // Result screen.
            _world.PrintResults(_width, _height, _stopWatch.GetTimeInSeconds());
        }
    }

    @Override
    public void keyPressed(KeyEvent event){
        if (event.getKeyCode() == KeyEvent.VK_P){
            TogglePause();
        }
        if (!_pause) {
            // Handle key press events.
            _world.HandleKeyEvents(event);
        }
        if (event.getKeyCode() == KeyEvent.VK_SPACE && _world.IsEndGame()){
            _world.HandleRestart();
        }
    }

    // Pause the game engine during message popups.
    public void PauseEngine(){
        _pause = true;
        _stopWatch.Stop();
    }

    // Resumes the game engine.
    public void ResumeEngine(){
        _pause = false;
        _stopWatch.Start();
    }

    public boolean IsPause(){
        return _pause;
    }

    // Get the current frame for animation.
    public int GetFrameIndex(double time, double scale, int totalImages) {
        return (int) Math.floor(((time % scale) / scale) * totalImages);
    }

    // Turn the background music on/off.
    public void ToggleMusic(){
        ToggleMusic(GameOptions.MasterVolume);
    }

    // Turn the background music on/off.
    public void ToggleMusic(float volume){
        if(GameOptions.EnableMusic){
            startAudioLoop(_gameAudio.Theme, volume);
        }
        else{
            stopAudioLoop(_gameAudio.Theme);
        }
    }

    // Toggle pause.
    public void TogglePause(){
        if(_pause){
            ResumeEngine();
        }
        else{
            PauseEngine();
        }
    }

    // Load image with stream - works for IDE and Jar.
    @Override
    public Image loadImage(String filename) {
        try {
            var stream = getClass().getResourceAsStream(filename);

            if (stream != null) {
                return ImageIO.read(stream);
            }
        } catch (IOException e) {
            // Show Error Message
            System.out.println("Error: could not load image " + filename);
            System.exit(1);
        }

        // Return null
        return null;
    }

    // Load audio from stream.
    @Override
    public AudioClip loadAudio(String filename) {
        try {
            // Open File
            var stream = getClass().getResourceAsStream(filename);

            if (stream != null) {
                // Open Audio Input Stream
                AudioInputStream audio = AudioSystem.getAudioInputStream(new BufferedInputStream(stream));

                // Return Audio Clip
                return new AudioClip(audio);
            }
        } catch (Exception e) {
            // Catch Exception
            System.out.println("Error: cannot open Audio File " + filename + "\n" + e.getMessage());
        }

        // Return Null
        return null;
    }
}
