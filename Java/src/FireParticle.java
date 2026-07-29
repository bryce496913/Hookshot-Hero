import java.awt.*;

public class FireParticle extends Particle {
    private float red,green,blue;
    @Override
    public void draw(GameEngine g) {
        if(notvisible())
            return;
        g.saveCurrentTransform();
        g.translate(x,y);
        g.scale(scale*0.5,scale*0.5);
        float angle=(float)Math.atan2(vy,vx);
        g.rotate((180*angle)/Math.PI+90);
        g.changeColor(new Color(red,green,blue,alpha));
        g.mGraphics.fillOval(-15,-30,30,60);
        g.restoreLastTransform();
    }

    static float smoothstep(float x) {
        if(x<0) x=0;
        if(x>1.0f) x=1.0f;
        return x * x * (3.0f - 2.0f * x);
    }
    @Override
    public void update(float dt) {
        super.update(dt);
        scale=0.1f+0.10f*(float)Math.log(time*100f);
        alpha=1.0f-smoothstep(time*3f);
        red=1.0f;
        green=(float) Math.exp(-time*4.5f);
        blue=(float) Math.exp(-time*10f);
    }
}
