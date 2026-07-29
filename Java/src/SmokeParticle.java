import java.awt.Image;
import java.awt.AlphaComposite;

public class SmokeParticle extends Particle{

    private float angle;
    private float rotationspeed;

    private final Image image;
    SmokeParticle(Image i) {
        image=i;
    }
    @Override
    void init(float startx, float starty, float emitterangle) {
        super.init(startx,starty,emitterangle);
        angle=(float)Math.random()*360f;
        rotationspeed=(float)Math.random()*20.0f-10.0f;
    }
    @Override
    public void draw(GameEngine g) {
        if(notvisible())
            return;
        g.saveCurrentTransform();
        g.translate(x,y-20);
        g.rotate(angle);
        g.scale(scale*0.5,scale*0.5);
        g.mGraphics.setComposite(AlphaComposite.getInstance(AlphaComposite.SRC_OVER,alpha));
        g.drawImage(image, -64, -64);
        g.mGraphics.setComposite(AlphaComposite.SrcOver);
        g.restoreLastTransform();
    }
    @Override
    public void update(float dt) {
        super.update(dt);
        angle=time+30*rotationspeed*(float)Math.exp(-time*2f);
        scale=0.1f+0.10f*(float)Math.log(time*100f+1);
        alpha=0.7f*(float)Math.exp(-time*2.5f);
    }
}
