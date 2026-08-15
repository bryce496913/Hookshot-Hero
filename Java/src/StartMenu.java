import javax.imageio.ImageIO;
import javax.sound.sampled.*;
import javax.swing.*;
import javax.swing.text.DefaultCaret;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.BufferedInputStream;
import java.io.File;
import java.io.IOException;
import java.util.concurrent.CompletableFuture;

public class StartMenu{
    private final int _width = 600, _height = 650, _fps = 120;
    private JFrame frame;
    private JPanel panel;
    private JButton easyModeButton;
    private JButton normalModeButton;
    private JButton missionModeButton;
    private JButton levelSelectButton;
    private JButton helpButton;
    private JButton quitButton;
    private Image mainImage;
    private Image gameTitle;
    private final AudioClip startTheme;
    public HookshotHeroesGameEngine Engine;
    public GameOptions GameOptions;

    public StartMenu() {
        mainImage = loadImage("MainImage.png");
        gameTitle = loadImage("GameTitle.png");
        startTheme = loadAudio("start.wav");
        startAudioLoop(startTheme, 0);
        GameOptions = new GameOptions();
        GameOptions.Width = _width;
        GameOptions.Height = _height;
        Engine = new HookshotHeroesGameEngine(GameOptions);
    }

    public void show() {
        // UI Menu
        frame = new JFrame("Hookshot Heroes");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setSize(300, 600);
        frame.setLocationRelativeTo(null);
        frame.setResizable(false);

        // Create a panel with a BorderLayout
        panel = new JPanel(new BorderLayout());

        // Create a JLabel with the mainImage as the background
        JLabel backgroundImageLabel = new JLabel(new ImageIcon(mainImage));
        panel.add(backgroundImageLabel, BorderLayout.CENTER);

        // Create a sub-panel with a GridLayout for the buttons
        JPanel buttonPanel = new JPanel(new GridLayout(6, 1));

        easyModeButton = new JButton("Single Player Game");
        normalModeButton = new JButton("Double Player Game");
        missionModeButton = new JButton("Quest Game");
        levelSelectButton = new JButton("Level Select (Debug)");
        helpButton = new JButton("Help");
        quitButton = new JButton("Quit");

        easyModeButton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                stopAudioLoop(startTheme);

                // Start single player mode game
                GameOptions.SinglePlayerMode = true;

                Engine.createGame(Engine, 120);
                frame.dispose(); // Close the start menu window;
            }
        });

        normalModeButton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                stopAudioLoop(startTheme);

                // Start the 2 player mode game
                // Start single player mode game
                GameOptions.SinglePlayerMode = false;
                GameOptions.DoublePlayerMode = true;

                Engine.createGame(Engine, 120);
                frame.dispose(); // Close the start menu window
            }
        });

        missionModeButton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                stopAudioLoop(startTheme);

                // Start quest game.
                GameOptions.SinglePlayerMode = true;
                GameOptions.DoublePlayerMode = false;
                GameOptions.MissionMode = true;

                Engine.createGame(Engine, 120);
                frame.dispose(); // Close the start menu window
            }
        });

        levelSelectButton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                showLevelSelect();
            }
        });

        helpButton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                // Open the help.txt file
                CompletableFuture.runAsync(() -> {
                    try {
                        DefaultMenuBarBuilder.CreateHelpScreen();
                    } catch (IOException ex) {
                        // Handle any exceptions
                        ex.printStackTrace();
                    }
                });
            }
        });

        quitButton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                // Quit the application
                System.exit(0);
            }
        });

        // Add the buttons to the sub-panel
        buttonPanel.add(easyModeButton);
        buttonPanel.add(normalModeButton);
        buttonPanel.add(missionModeButton);
        buttonPanel.add(levelSelectButton);
        buttonPanel.add(helpButton);
        buttonPanel.add(quitButton);

        // Add the sub-panel to the main panel
        panel.add(buttonPanel, BorderLayout.SOUTH);

        // Create a JLabel with the gameTitle image
        JLabel gameTitleLabel = new JLabel(new ImageIcon(gameTitle));
        panel.add(gameTitleLabel, BorderLayout.NORTH);

        // Set the main panel as the content pane of the frame
        frame.setContentPane(panel);
        frame.setVisible(true);
    }

    private void showLevelSelect() {
        JDialog levelSelectDialog = new JDialog(frame, "Debug Level Select", true);
        JPanel levelPanel = new JPanel(new GridLayout(0, 1, 4, 4));
        levelPanel.setBorder(BorderFactory.createEmptyBorder(8, 8, 8, 8));

        for (LevelDefinition levelDefinition : LevelDefinition.values()) {
            JButton levelButton = new JButton(levelDefinition.GetDisplayName());
            levelButton.addActionListener(e -> startDebugLevel(levelDefinition, levelSelectDialog));
            levelPanel.add(levelButton);
        }

        levelSelectDialog.setContentPane(new JScrollPane(levelPanel));
        levelSelectDialog.setSize(320, 440);
        levelSelectDialog.setLocationRelativeTo(frame);
        levelSelectDialog.setVisible(true);
    }

    private void startDebugLevel(LevelDefinition levelDefinition, JDialog levelSelectDialog) {
        stopAudioLoop(startTheme);

        // Debug level selection always starts a clean single-player session.
        GameOptions.SinglePlayerMode = true;
        GameOptions.DoublePlayerMode = false;
        GameOptions.MissionMode = false;
        Engine.InitializeDebugLevel(GameOptions, levelDefinition);

        levelSelectDialog.dispose();
        frame.dispose();
        Engine.createGame(Engine, _fps);
    }

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

    public StartMenu.AudioClip loadAudio(String filename) {
        try {
            // Open File
            var stream = getClass().getResourceAsStream(filename);

            if (stream != null) {
                // Open Audio Input Stream
                AudioInputStream audio = AudioSystem.getAudioInputStream(new BufferedInputStream(stream));

                // Return Audio Clip
                return new StartMenu.AudioClip(audio);
            }
        } catch (Exception e) {
            // Catch Exception
            System.out.println("Error: cannot open Audio File " + filename + "\n" + e.getMessage());
        }

        // Return Null
        return null;
    }

    public void startAudioLoop(StartMenu.AudioClip audioClip, float volume) {
        // Check audioClip for null
        if(audioClip == null) {
            // Print error message
            System.out.println("Error: audioClip is null\n");

            // Return
            return;
        }

        // Get Loop Clip
        Clip clip = audioClip.getLoopClip();

        // Create Loop Clip if necessary
        if(clip == null) {
            try {
                // Create a Clip
                clip = AudioSystem.getClip();

                // Load data
                clip.open(audioClip.getAudioFormat(), audioClip.getData(), 0, (int)audioClip.getBufferSize());

                // Create Controls
                FloatControl control = (FloatControl)clip.getControl(FloatControl.Type.MASTER_GAIN);

                // Set Volume
                control.setValue(volume);

                // Set Clip to Loop
                clip.loop(Clip.LOOP_CONTINUOUSLY);

                // Set Loop Clip
                audioClip.setLoopClip(clip);
            } catch(Exception exception) {
                // Display Error Message
                System.out.println("Error: could not play Audio Clip\n");
                System.out.println(exception.getMessage());
            }
        }

        // Set Frame Position to 0
        clip.setFramePosition(0);

        // Start Audio Clip playing
        clip.start();
    }

    public void stopAudioLoop(StartMenu.AudioClip audioClip) {
        // Get Loop Clip
        Clip clip = audioClip.getLoopClip();

        // Check clip is not null
        if(clip != null){
            // Stop Clip playing
            clip.stop();
        }
    }

    public class AudioClip {
        // Format
        AudioFormat mFormat;

        // Audio Data
        byte[] mData;

        // Buffer Length
        long mLength;

        // Loop Clip
        Clip mLoopClip;

        public Clip getLoopClip() {
            // return mLoopClip
            return mLoopClip;
        }

        public void setLoopClip(Clip clip) {
            // Set mLoopClip to clip
            mLoopClip = clip;
        }

        public AudioFormat getAudioFormat() {
            // Return mFormat
            return mFormat;
        }

        public byte[] getData() {
            // Return mData
            return mData;
        }

        public long getBufferSize() {
            // Return mLength
            return mLength;
        }

        public AudioClip(AudioInputStream stream) {
            // Get Format
            mFormat = stream.getFormat();

            // Get length (in Frames)
            mLength = stream.getFrameLength() * mFormat.getFrameSize();

            // Allocate Buffer Data
            mData = new byte[(int)mLength];

            try {
                // Read data
                stream.read(mData);
            } catch(Exception exception) {
                // Print Error
                System.out.println("Error reading Audio File\n");

                // Exit
                System.exit(1);
            }

            // Set LoopClip to null
            mLoopClip = null;
        }
    }

    public static void main(String[] args) {
        StartMenu startMenu = new StartMenu();
        startMenu.show();
    }
}
