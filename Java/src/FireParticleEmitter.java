public class FireParticleEmitter extends ParticleEmitter{

    FireParticleEmitter() {
        super();
    }

    @Override
    FireParticle newParticle() {
        return new FireParticle();
    }
}