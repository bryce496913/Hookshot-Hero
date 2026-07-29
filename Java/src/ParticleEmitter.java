import java.awt.*;
import java.util.ArrayList;

public abstract class ParticleEmitter {
    int nparticles;
    float emitterfrequency;
    float sweepangle;
    float sweepspeed;
    float sweeprandom;
    ArrayList<Particle> particles;
    float emitterangle=0;
    float startx,starty;
    float angle=0f;
    float time=0;
    float lastemittime=0;

    ParticleEmitter(int nparticles, int emitterfrequency, float sweepangle, float sweepspeed, float sweeprandom) {
        this.nparticles=nparticles;
        this.emitterfrequency=emitterfrequency;
        this.sweepangle=sweepangle;
        this.sweepspeed=sweepspeed;
        this.sweeprandom=sweeprandom;
        this.particles=new ArrayList<>(nparticles);
    }

    ParticleEmitter() {
        this(120, 100,.04f,40,.1f);
    }
    abstract Particle newParticle();

    public void move(float x, float y) {
        startx=x;
        starty=y;
    }

    // gets a particle that is no longer visible
    // or makes a new one if the pool is not full
    Particle getParticle() {
        if(particles.size() < nparticles) {
            Particle p = newParticle();
            particles.add(p);
            return p;
        }
        for(Particle p:particles) {
            if(p.notvisible()) {
                return p;
            }
        }
        return null; // if pool is full and all particles are visible
    }

    public void update (float dt) {
        time+=dt;
        emitterangle=angle+(float)Math.sin(time*sweepspeed)*sweepangle*(float)Math.PI+(float)Math.PI+(float)Math.random()*sweeprandom-sweeprandom/2.0f;
        if (time>lastemittime+1.0/emitterfrequency) {
            Particle p=getParticle();
            if(p!=null)
                p.init(startx,starty,emitterangle);
            lastemittime=time;
        }
        for(Particle p:particles) {
            p.update(dt);
        }
    }

    public void draw(GameEngine ge) {
        for(Particle p:particles) {
            if(!p.notvisible())
                p.draw(ge);
        }
    }
}
