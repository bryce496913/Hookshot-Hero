import java.awt.*;
//From Here

public class Levels {
    public HookshotHeroesGameEngine Engine;
    public GameImage GameImage;
    public GameOptions GameOptions;
    int environmentSpriteSize = 40;

    public Levels (HookshotHeroesGameEngine engine, GameImage gameImage, GameOptions gameOptions){
        Engine = engine;
        GameImage = gameImage;
        GameOptions = gameOptions;
    }

    public void drawWallFrontWithCollision(int x, int y) {
        Engine.drawImage(GameImage.wallGreyFront, x, y);
        Engine.changeColor(Color.red); //Just to see visually
        Engine.drawRectangle(x, y, 40, 40);

        //Add collision logic here
    }

    public void wallSideCollision(int x, int y) {
        Engine.changeColor(Color.red); // Just to see visually
        Engine.drawRectangle(x, y, 40, 40);

        //Add collision logic here
    }

    public void doorCollision(int x, int y) {
        Engine.changeColor(Color.green); // Just to see visually
        Engine.drawRectangle(x, y, 40, 40);

        //Add collision logic here
    }

    public void drawLavaWithCollision(int x, int y) {
        Engine.drawImage(GameImage.lava, x, y);
        Engine.changeColor(Color.pink); // Just to see visually
        Engine.drawRectangle(x, y, 40, 40);

        //Add collision logic here
    }

    public void basicLevelEnvironment() {
        //Floor
        for (int y = 0; y < GameOptions.Width; y += 100) {
            for (int x = 0; x < GameOptions.Height; x += 100) {
                Engine.drawImage(GameImage.floor, x, y);
            }
        }

        for (int x = 0; x < GameOptions.Width; x += environmentSpriteSize) {
            // Draw wall sprite on the top side
            drawWallFrontWithCollision(x, 0);

            // Draw wall sprite on the bottom side
            drawWallFrontWithCollision(x, GameOptions.Width - environmentSpriteSize);
        }
        for (int y = 0; y < GameOptions.Width - environmentSpriteSize; y += environmentSpriteSize) {
            // Draw wall sprite on the left side
            Engine.drawImage(GameImage.wallGreyLeftSide, 0, y);
            wallSideCollision(0, y);

            // Draw wall sprite on the right side
            Engine.drawImage(GameImage.wallGreyRightSide, GameOptions.Width - environmentSpriteSize, y);
            wallSideCollision(GameOptions.Width - environmentSpriteSize, y);
        }
    }

    public void levelOne() {

        basicLevelEnvironment();

        // Draw Lava
        for (int x = 40; x < 560; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 240);
            drawLavaWithCollision(x, 280);
            drawLavaWithCollision(x, 320);
        }

        //Internal walls
        for (int x = 200; x < 400; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 160);
        }

        //Draw doors
        Engine.drawImage(GameImage.DoorGreyOpen, 280,0);
        doorCollision(280,0);
        Engine.drawImage(GameImage.DoorGreyClosed, 280,560);
        doorCollision(280,560);

    }

    public void levelTwo() {
        basicLevelEnvironment();

        // Draw internal walls
        for (int x = 40; x < 440; x += environmentSpriteSize) {
            Engine.drawImage(GameImage.wallGreyFront, x, 160);
            drawWallFrontWithCollision(x, 160);
        }
        for (int x = 80; x < 160; x += environmentSpriteSize) {
            Engine.drawImage(GameImage.wallGreyFront, x, 240);
            drawWallFrontWithCollision(x, 240);
        }
        for (int x = 360; x < 440; x += environmentSpriteSize) {
            Engine.drawImage(GameImage.wallGreyFront, x, 200);
            drawWallFrontWithCollision(x, 200);
            Engine.drawImage(GameImage.wallGreyFront, x, 240);
            drawWallFrontWithCollision(x, 240);
        }

        // Draw Lava
        for (int x = 40; x < 560; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 320);
            drawLavaWithCollision(x, 360);
            drawLavaWithCollision(x, 400);
        }
        for (int x = 360; x < 560; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 440);
            drawLavaWithCollision(x, 480);
            drawLavaWithCollision(x, 520);
        }
        for (int x = 200; x < 320; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 200);
            drawLavaWithCollision(x, 240);
            drawLavaWithCollision(x, 280);
        }

        //Draw doors
        Engine.drawImage(GameImage.DoorGreyOpen, 280,0);
        doorCollision(280,0);
        Engine.drawImage(GameImage.DoorGreyClosed, 280,560);
        doorCollision(280,560);
    }

    public void levelThree() {
        basicLevelEnvironment();

        // Draw internal walls
        for (int x = 240; x < 480; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 120);
        }
        for (int y = 40; y < 120; y += environmentSpriteSize) {
            drawWallFrontWithCollision(240, y);
        }
        for (int y = 400; y < 560; y += environmentSpriteSize) {
            drawWallFrontWithCollision(240, y);
        }
        for (int x = 240; x < 480; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 400);
        }
        for (int x = 320; x < 600; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 240);
        }
        for (int y = 320; y <= 360; y += 40) {
            for (int x = 20; x <= 40; x += 20) {
                drawWallFrontWithCollision(x, y);
            }
        }
        drawWallFrontWithCollision(320, 280);
        drawWallFrontWithCollision(80, 520);

        // Draw Lava
        for (int y = 40; y < 320; y += environmentSpriteSize) {
            for (int x = 40; x < 220; x += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int y = 320; y < 560; y += environmentSpriteSize) {
            for (int x = 120; x < 220; x += 20) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 40; x <= 40; x += environmentSpriteSize) {
            for (int y = 400; y <= 520; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 400; x <= 480; x += environmentSpriteSize) {
            for (int y = 280; y <= 360; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 520; x <= 520; x += environmentSpriteSize) {
            for (int y = 320; y <= 400; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int y = 400; y <= 440; y += environmentSpriteSize) {
            drawLavaWithCollision(80, y);
        }
        for (int y = 80; y <= 120; y += environmentSpriteSize) {
            for (int x = 480; x <= 540; x += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        drawLavaWithCollision(480, 400);

        //Draw doors
        Engine.drawImage(GameImage.DoorGreyOpen, 280,0);
        doorCollision(280,0);
        Engine.drawImage(GameImage.DoorGreyClosed, 280,560);
        doorCollision(280,560);
    }

    public void levelFour() {
        basicLevelEnvironment();

        //Draw doors
        Engine.drawImage(GameImage.DoorGreyOpen, 280,0);
        doorCollision(280,0);
        Engine.drawImage(GameImage.DoorGreyOpenSide, 560,280);
        doorCollision(560,280);
        Engine.drawImage(GameImage.DoorGreyClosed, 280,560);
        doorCollision(280,560);
    }

    public void levelFive() {
        basicLevelEnvironment();

        //Draw lava
        for (int y = 400; y < 520; y += environmentSpriteSize) {
            for (int x = 40; x < 300; x += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int y = 400; y < 520; y += environmentSpriteSize) {
            for (int x = 400; x < 520; x += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int y = 200; y < 320; y += environmentSpriteSize) {
            for (int x = 320; x < 400; x += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int y = 40; y < 120; y += environmentSpriteSize) {
            for (int x = 400; x < 520; x += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 80; x < 200; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 200);
        }
        for (int y = 240; y < 360; y += environmentSpriteSize) {
            drawLavaWithCollision(280, y);
        }
        for (int x = 120; x < 280; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 360);
        }
        for (int x = 120; x < 240; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 520);
        }
        drawLavaWithCollision(40, 40);
        drawLavaWithCollision(80, 40);
        drawLavaWithCollision(120, 80);

        drawLavaWithCollision(240, 40);
        drawLavaWithCollision(240, 80);
        drawLavaWithCollision(280, 80);

        drawLavaWithCollision(400, 200);
        drawLavaWithCollision(400, 240);

        //Draw doors
        Engine.drawImage(GameImage.DoorGreyClosedSide, 0,80);
        doorCollision(0,80);
        Engine.drawImage(GameImage.DoorGreyOpen, 280,0);
        doorCollision(280,0);

        //Draw inner walls
        for (int x = 320; x < 520; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 120);
        }
        for (int x = 320; x < 440; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 160);
        }
        for (int x = 40; x < 280; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 160);
        }
        for (int x = 40; x < 280; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 240);
        }
        for (int x = 80; x < 280; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 320);
        }
        for (int y = 320; y < 560; y += environmentSpriteSize) {
            drawWallFrontWithCollision(320, y);
        }
        for (int y = 200; y < 400; y += environmentSpriteSize) {
            for (int x = 440; x < 520; x += environmentSpriteSize) {
                drawWallFrontWithCollision(x, y);
            }
        }
        for (int y = 80; y < 160; y += environmentSpriteSize) {
            drawWallFrontWithCollision(160, y);
        }
        drawWallFrontWithCollision(320, 80);
        drawWallFrontWithCollision(40, 520);

        drawWallFrontWithCollision(520, 440);

        drawWallFrontWithCollision(360, 520);

        drawWallFrontWithCollision(360, 320);
        drawWallFrontWithCollision(360, 360);
    }

    public void levelSix() {
        basicLevelEnvironment();

        //Draw lava
        for (int x = 80; x < 200; x += 40) {
            drawLavaWithCollision(x, 40);
        }
        for (int x = 200; x < 320; x += environmentSpriteSize) {
            for (int y = 80; y < 200; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 400; x < 520; x += environmentSpriteSize) {
            for (int y = 200; y < 360; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int x = 200; x < 320; x += environmentSpriteSize) {
            for (int y = 400; y < 520; y += environmentSpriteSize) {
                drawLavaWithCollision(x, y);
            }
        }
        for (int y = 240; y < 440; y += environmentSpriteSize) {
            drawLavaWithCollision(520, y);
        }
        for (int y = 200; y < 280; y += environmentSpriteSize) {
            drawLavaWithCollision(40, y);
        }
        for (int y = 320; y < 440; y += environmentSpriteSize) {
            drawLavaWithCollision(80, y);
        }
        for (int y = 400; y < 520; y += environmentSpriteSize) {
            drawLavaWithCollision(120, y);
        }
        for (int y = 400; y < 480; y += environmentSpriteSize) {
            drawLavaWithCollision(40, y);
        }
        for (int x = 160; x < 280; x += environmentSpriteSize) {
            drawLavaWithCollision(x, 520);
        }
        drawLavaWithCollision(360, 320);

        //Draw internal walls
        for (int x = 80; x < 200; x += environmentSpriteSize) {
            for (int y = 200; y < 280; y += environmentSpriteSize) {
                drawWallFrontWithCollision(x, y);
            }
        }
        for (int x = 400; x < 520; x += environmentSpriteSize) {
            for (int y = 360; y < 520; y += environmentSpriteSize) {
                drawWallFrontWithCollision(x, y);
            }
        }
        for (int x = 40; x < 200; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 120);
        }
        for (int x = 200; x < 360; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 320);
        }
        for (int x = 280; x < 400; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 240);
        }
        for (int x = 40; x < 120; x += environmentSpriteSize) {
            drawWallFrontWithCollision(x, 520);
        }
        for (int y = 280; y < 520; y += environmentSpriteSize) {
            drawWallFrontWithCollision(160, y);
        }
        for (int y = 400; y < 560; y += environmentSpriteSize) {
            drawWallFrontWithCollision(320, y);
        }
        for (int y = 80; y < 200; y += environmentSpriteSize) {
            drawWallFrontWithCollision(360, y);
        }
        for (int y = 40; y < 200; y += environmentSpriteSize) {
            drawWallFrontWithCollision(480, y);
        }
        drawWallFrontWithCollision(280, 40);
        drawWallFrontWithCollision(320, 120);
        drawWallFrontWithCollision(280, 200);
        drawWallFrontWithCollision(40, 320);
        drawWallFrontWithCollision(120, 280);
        drawWallFrontWithCollision(120, 320);
    }
}

