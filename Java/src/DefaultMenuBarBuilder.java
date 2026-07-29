import javax.swing.*;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

/****************************************************************************************
 * Builder for the default menu bar.
 ****************************************************************************************/
public class DefaultMenuBarBuilder implements IMenuBarBuilder{

    public HookshotHeroesGameEngine Engine;
    public GameOptions LocalOptions;

    // Create the menu bar and its items.
    // Add event handlers for each menu bar items.
    @Override
    public JMenuBar BuildMenuBar(HookshotHeroesGameEngine src) {
        Engine = src;

        var menuBar = new JMenuBar();
        var menuFile = new JMenu("File");
        var menuOptions = new JMenu("Options");

        var menuOptionsConfig = new JMenuItem(new AbstractAction("Game Configuration") {
            @Override
            public void actionPerformed(ActionEvent e) {
                Engine.PauseEngine();

                LocalOptions = new GameOptions();
                LocalOptions.EnableMusic = Engine.GameOptions.EnableMusic;
                LocalOptions.DoublePlayerMode = Engine.GameOptions.DoublePlayerMode;
                LocalOptions.SinglePlayerMode = Engine.GameOptions.SinglePlayerMode;
                LocalOptions.EnableBouncingBalls = Engine.GameOptions.EnableBouncingBalls;

                var singleGameButton = new JRadioButton("Single Player");
                singleGameButton.setActionCommand("Single");
                var doubleGameButton = new JRadioButton("Double Player");
                doubleGameButton.setActionCommand("Double");
                SetButtons(Engine.GameOptions, singleGameButton, doubleGameButton);
                var group = new ButtonGroup();
                group.add(singleGameButton);
                group.add(doubleGameButton);
                singleGameButton.addActionListener(new AbstractAction() {
                    @Override
                    public void actionPerformed(ActionEvent e) {
                        ConfigHandler(e, LocalOptions);
                    }
                });
                doubleGameButton.addActionListener(new AbstractAction() {
                    @Override
                    public void actionPerformed(ActionEvent e) {
                        ConfigHandler(e, LocalOptions);
                    }
                });

                var enableMusic = new JCheckBox("Enable Music");
                enableMusic.setActionCommand("Music");
                SetCheckBox(Engine.GameOptions.EnableMusic, enableMusic);
                enableMusic.addActionListener(new AbstractAction() {
                    @Override
                    public void actionPerformed(ActionEvent e) {
                        LocalOptions.EnableMusic = enableMusic.isSelected();
                    }
                });

                var enableBalls = new JCheckBox("Enable Bouncing Balls");
                enableBalls.setActionCommand("Balls");
                SetCheckBox(Engine.GameOptions.EnableBouncingBalls, enableBalls);
                enableBalls.addActionListener(new AbstractAction() {
                    @Override
                    public void actionPerformed(ActionEvent e) {
                        LocalOptions.EnableBouncingBalls = enableBalls.isSelected();
                    }
                });

                var  radioPanel = new JPanel(new GridLayout(0, 1));
                radioPanel.add(singleGameButton);
                radioPanel.add(doubleGameButton);
                radioPanel.add(enableMusic);
                //radioPanel.add(enableBalls);

                var configPanel = new JPanel();
                configPanel.add(radioPanel, BorderLayout.LINE_START);

                var result = JOptionPane.showConfirmDialog(null, configPanel,"Game Configuration",JOptionPane.OK_CANCEL_OPTION);
                if (result == 0){
                    // Check for UI changes.
                    if(LocalOptions.SinglePlayerMode != Engine.GameOptions.SinglePlayerMode ||
                            LocalOptions.DoublePlayerMode != Engine.GameOptions.DoublePlayerMode ||
                            LocalOptions.EnableBouncingBalls != Engine.GameOptions.EnableBouncingBalls) {
                        Engine.GameOptions.SinglePlayerMode = LocalOptions.SinglePlayerMode;
                        Engine.GameOptions.DoublePlayerMode = LocalOptions.DoublePlayerMode;
                        Engine.GameOptions.EnableBouncingBalls = LocalOptions.EnableBouncingBalls;
                        Engine.InitializeWorld(Engine.GameOptions);
                    }
                    if(LocalOptions.EnableMusic != Engine.GameOptions.EnableMusic) {
                        Engine.GameOptions.EnableMusic = LocalOptions.EnableMusic;
                        Engine.ToggleMusic();
                    }
                }
                else{
                    LocalOptions.SinglePlayerMode = Engine.GameOptions.SinglePlayerMode;
                    LocalOptions.DoublePlayerMode = Engine.GameOptions.DoublePlayerMode;
                    LocalOptions.EnableMusic = Engine.GameOptions.EnableMusic;
                    LocalOptions.EnableBouncingBalls = Engine.GameOptions.EnableBouncingBalls;
                    SetButtons(Engine.GameOptions, singleGameButton, doubleGameButton);
                    SetCheckBox(Engine.GameOptions.EnableMusic, enableMusic);
                    SetCheckBox(Engine.GameOptions.EnableBouncingBalls, enableBalls);
                }
                Engine.ResumeEngine();
            }
        });
        var menuHelp = new JMenu("Help");
        var menuFileNewGame = new JMenuItem(new AbstractAction("New Game") {
            @Override
            public void actionPerformed(ActionEvent e) {
                Engine.InitializeWorld(Engine.GameOptions);
            }
        });
        var menuFileReturnToMenu = new JMenuItem(new AbstractAction("Return to Menu") {
            @Override
            public void actionPerformed(ActionEvent e) {
                // Close current game window.
                Engine.GameOptions.EnableMusic = false;
                Engine.ToggleMusic();
                Engine.mFrame.setJMenuBar(null);
                Engine.mFrame.dispose();
                // Explicitly remove the dispatcher of previous engine object.
                KeyboardFocusManager.getCurrentKeyboardFocusManager().removeKeyEventDispatcher(Engine.keyEventDispatcher);
                Engine = null;
                // Open start menu.
                var menu = new StartMenu();
                menu.show();
                // Persist options.
                Engine = menu.Engine;
                LocalOptions = menu.Engine.GameOptions;
            }
        });
        var menuPauseGame = new JMenuItem(new AbstractAction("Pause / Resume (P)") {
            @Override
            public void actionPerformed(ActionEvent e) {
                Engine.TogglePause();
            }
        });
        var menuFileExit = new JMenuItem(new AbstractAction("Exit") {
            @Override
            public void actionPerformed(ActionEvent e) {
                System.exit(0);
            }
        });
        var menuHelpHow = new JMenuItem(new AbstractAction("How to play") {
            @Override
            public void actionPerformed(ActionEvent e) {
                try {
                    CreateHelpScreen();
                } catch (IOException ex) {
                    throw new RuntimeException(ex);
                }
            }
        });
        var menuHelpAbout = new JMenuItem(new AbstractAction("About") {
            @Override
            public void actionPerformed(ActionEvent e) {
                Engine.PauseEngine();
                JOptionPane.showMessageDialog(Engine.mFrame, """
                        Icons, terrain sprites and sound effects: https://opengameart.org/
                        
                        Lidia, Shura and characters sprite models:
                        https://opengameart.org/content/lpc-heroine
                        https://opengameart.org/content/lpc-heroine-2
                        https://opengameart.org/content/whispers-of-avalon-archer-sprite
                        https://opengameart.org/content/edited-and-extended-24x32-character-pack
                        https://opengameart.org/content/sara-2-0
                        
                        Theme Music:
                        https://soundcloud.com/video-background-music/scarey-atmospheres-chapter-3
                        https://opengameart.org/content/lava-area-theme
                        https://opengameart.org/content/pretty-maiden-medievalfantasy-game-cheerful-opening
                        
                        MIT License
                        
                        Copyright (c) 2023 Jerry Hsiung
                        
                        Permission is hereby granted, free of charge, to any person obtaining a copy
                        of this software and associated documentation files (the "Software"), to deal
                        in the Software without restriction, including without limitation the rights
                        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
                        copies of the Software, and to permit persons to whom the Software is
                        furnished to do so, subject to the following conditions:

                        The above copyright notice and this permission notice shall be included in all
                        copies or substantial portions of the Software.

                        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
                        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
                        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
                        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
                        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
                        SOFTWARE.
                        """);
                Engine.ResumeEngine();
            }
        });

        menuBar.add(menuFile);
        menuBar.add(menuOptions);
        menuBar.add(menuHelp);
        menuFile.add(menuPauseGame);
        menuFile.add(menuFileNewGame);
        menuFile.add(menuFileReturnToMenu);
        menuFile.add(menuFileExit);
        menuOptions.add(menuOptionsConfig);
        menuHelp.add(menuHelpHow);
        menuHelp.add(menuHelpAbout);

        return menuBar;
    }

    // Copy data from UI to game options.
    private void ConfigHandler(ActionEvent e, GameOptions options){
        if(e.getActionCommand().equals("Single")){
            options.SinglePlayerMode = true;
            options.DoublePlayerMode = false;
        }
        else if(e.getActionCommand().equals("Double")){
            options.SinglePlayerMode = false;
            options.DoublePlayerMode = true;
        }
    }

    // Copy data from game options to UI for radio buttons.
    private void SetButtons(GameOptions options, JRadioButton singleGameButton, JRadioButton doubleGameButton){
        if(options.SinglePlayerMode) {
            singleGameButton.setSelected(true);
        }
        else {
            doubleGameButton.setSelected(true);
        }
    }

    // Copy data from game options to check box.
    private void SetCheckBox(boolean state, JCheckBox checkBox){
        checkBox.setSelected(state);
    }

    public static void CreateHelpScreen() throws IOException {
        JFrame frame = new JFrame("Help");
        frame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        JPanel panel = new JPanel();
        panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));
        JTextArea textArea = new JTextArea(15, 50);
        textArea.setWrapStyleWord(true);
        textArea.setEditable(false);
        Font defaultFont = new JMenu().getFont();
        textArea.setFont(defaultFont);
        JScrollPane scroller = new JScrollPane(textArea);
        scroller.setVerticalScrollBarPolicy(ScrollPaneConstants.VERTICAL_SCROLLBAR_ALWAYS);
        scroller.setHorizontalScrollBarPolicy(ScrollPaneConstants.HORIZONTAL_SCROLLBAR_NEVER);
        panel.add(scroller);
        frame.getContentPane().add(BorderLayout.CENTER, panel);
        frame.pack();
        frame.setVisible(true);
        frame.setResizable(false);
        frame.setLocationRelativeTo(null);

        var stream = DefaultMenuBarBuilder.class.getResourceAsStream("help.txt");
        var streamReader = new InputStreamReader(stream, "UTF-8");
        BufferedReader in = new BufferedReader(streamReader);
        var sb = new StringBuilder();
        for (String line; (line = in.readLine()) != null;) {
            sb.append(line);
            sb.append(System.lineSeparator());
        }
        textArea.setText(sb.toString());
        textArea.setCaretPosition(0);
        in.close();
        streamReader.close();
        stream.close();
    }
}
