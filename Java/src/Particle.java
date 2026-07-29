public abstract class Particle {
    protected float x,y;
    protected float vx,vy;
    protected float scale;
    protected float alpha;
    protected float time;
    protected float maxlifetime=2;

    float getInitialSpeed() {
        return 2.0f*((float)Math.random()*80.0f+150f);
    }

    void init(float startx, float starty, float emitterangle) {
        x=startx;
        y=starty;
        float initialspeed=getInitialSpeed();
        vy=initialspeed*(float)Math.cos(emitterangle);
        vx=initialspeed*(float)Math.sin(emitterangle);
        scale=(float)Math.random()*0.1f+.02f;
        alpha=(float)Math.random()*0.1f+0.9f;
        time=0;
    }

    boolean notvisible() {
        return (alpha <= 0.02f || time > maxlifetime);
    }

    public void update(float dt) {
        time+=dt;
        x+=vx*dt;
        y+=vy*dt;
    }

    public abstract void draw(GameEngine ge);
}
