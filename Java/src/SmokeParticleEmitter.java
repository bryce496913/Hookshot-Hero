import java.awt.Image;
public class SmokeParticleEmitter extends ParticleEmitter {
    public final GameImage GameImage;
    SmokeParticleEmitter(GameImage gameImage) {
        super();
        GameImage = gameImage;
    }
    @Override
    SmokeParticle newParticle() {
        //SmokeParticle p=new SmokeParticle(image[(int)(Math.random()*2)+1]);
        SmokeParticle p = new SmokeParticle(GameImage.Smokes[2]);
        return p;
    }
}
