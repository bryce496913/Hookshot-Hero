import Combine
import SpriteKit

enum TextureError: LocalizedError { case missing(String); var errorDescription: String? { if case .missing(let f)=self { return "Required Level 1 texture is missing: \(f)" }; return nil } }
final class LegacyTextureLoader {
    private var cache: [String: SKTexture] = [:]
    func texture(_ name: String) throws -> SKTexture { if let t=cache[name] { return t }; guard let url=Bundle.main.url(forResource: name, withExtension: nil) else { throw TextureError.missing(name) }; let t=SKTexture(imageNamed: url.lastPathComponent); t.filteringMode = .nearest; cache[name]=t; return t }
    func slice(_ name:String, x:CGFloat,y:CGFloat,width:CGFloat,height:CGFloat,sheetWidth:CGFloat,sheetHeight:CGFloat) throws -> SKTexture { let base=try texture(name); let rect=SpriteSheet.normalizedRect(x:x,y:y,width:width,height:height,sheetWidth:sheetWidth,sheetHeight:sheetHeight); let t=SKTexture(rect: rect, in: base); t.filteringMode = .nearest; return t }
}
enum SpriteSheet { static func normalizedRect(x:CGFloat,y:CGFloat,width:CGFloat,height:CGFloat,sheetWidth:CGFloat,sheetHeight:CGFloat)->CGRect { .init(x:x/sheetWidth,y:1-((y+height)/sheetHeight),width:width/sheetWidth,height:height/sheetHeight) } }

@MainActor final class GameScene: SKScene {
    private let session: GameSession; private let loader=LegacyTextureLoader(); private(set) var clock=SimulationClock()
    private let world=SKNode(), chain=SKShapeNode(), hook=SKShapeNode(circleOfRadius: 3); private var playerNode=SKSpriteNode(); private var entityNodes:[EntityID:SKNode]=[:]
    private var stateObservation:AnyCancellable?; private var cellSize:CGFloat=1; private var boardOrigin=CGPoint.zero
    init(size:CGSize = .init(width:600,height:600),session:GameSession){self.session=session;super.init(size:size);scaleMode = .resizeFill;backgroundColor = .black}
    required init?(coder:NSCoder){nil}
    override func didMove(to view:SKView){ build(); bind(); clock.reset() }
    override func didChangeSize(_ oldSize:CGSize){ super.didChangeSize(oldSize); layoutWorld() }
    override func update(_ currentTime:TimeInterval){guard session.canSimulate else{clock.reset();return};session.advance(by:clock.delta(at:currentTime));renderDynamic()}
    override func willMove(from view:SKView){clock.reset();stateObservation?.cancel();stateObservation=nil}
    private func bind(){stateObservation=session.$state.sink{[weak self] _ in self?.clock.reset()}}
    private func build(){guard world.parent == nil else{return};removeAllChildren();addChild(world);guard let sim=session.simulation else{return showError(session.initializationError ?? "Level 1 could not be initialized.")}
        do { let floor=try loader.texture("floor.png"), wall=try loader.texture("wallGreyFront.png"), lava=try loader.texture("lava.png")
            let bg=SKSpriteNode(texture:floor);bg.anchorPoint=.zero;bg.size=.init(width:60,height:60);bg.position=.zero;bg.zPosition=0;world.addChild(bg)
            for region in sim.level.lava { addTile(region,texture:lava,z:1) };for region in sim.level.walls { addTile(region,texture:wall,z:2) }
            let open=SKSpriteNode(texture:try loader.texture("DoorGreyOpen.png"));open.position=point(sim.level.exitAnchor);open.size=.init(width:6,height:3);open.zPosition=3;world.addChild(open)
            let closed=SKSpriteNode(texture:try loader.texture("DoorGreyClosed.png"));closed.position=point(sim.level.entryAnchor);closed.size=.init(width:6,height:4);closed.zPosition=3;world.addChild(closed)
            let chest=SKSpriteNode(texture:try loader.slice("chests.png",x:291,y:67,width:25,height:25,sheetWidth:512,sheetHeight:512));chest.name="chest";chest.position=point(sim.level.chestAnchor);chest.size=.init(width:3,height:3);chest.zPosition=5;world.addChild(chest)
            playerNode=SKSpriteNode(texture:try lidiaTexture(sim.player.facing));playerNode.size=.init(width:3.2,height:3.2);playerNode.zPosition=8;world.addChild(playerNode)
            chain.strokeColor = .white;chain.lineWidth=0.35;chain.zPosition=7;hook.fillColor = .systemYellow;hook.setScale(0.15);hook.zPosition=8;world.addChild(chain);world.addChild(hook)
            for entity in sim.entities { let n=try node(entity);entityNodes[entity.id]=n;world.addChild(n) };layoutWorld();renderDynamic()
        } catch {showError(error.localizedDescription)}
    }
    private func addTile(_ r:GridRegion,texture:SKTexture,z:CGFloat){let n=SKSpriteNode(texture:texture);n.anchorPoint=.zero;n.position=.init(x:CGFloat(r.columns.lowerBound),y:CGFloat(60-r.rows.upperBound));n.size=.init(width:r.columns.count,height:r.rows.count);n.zPosition=z;world.addChild(n)}
    private func node(_ e:WorldEntity)throws->SKNode{let texture:SKTexture;switch e.kind{case .coin:texture=try loader.texture("goldCoin1.png");case .mine:texture=try loader.slice("bomb.png",x:0,y:0,width:20,height:26,sheetWidth:80,sheetHeight:26);case .cabbage:texture=try loader.slice("barrels.png",x:64,y:32,width:32,height:32,sheetWidth:256,sheetHeight:256)};let n=SKSpriteNode(texture:texture);n.position=point(e.position);n.size=.init(width:2.2,height:2.2);n.zPosition=6;return n}
    private func lidiaTexture(_ d:GridDirection, frame:Int = 0)throws->SKTexture{let row:[GridDirection:CGFloat]=[.up:0,.left:1,.down:2,.right:3][d] ?? 3;return try loader.slice("lidia.png",x:CGFloat(frame % 9)*64,y:row*64,width:64,height:64,sheetWidth:576,sheetHeight:256)}
    private func point(_ p:GridPosition)->CGPoint{.init(x:CGFloat(p.column)+0.5,y:CGFloat(60-p.row)-0.5)}
    private func renderDynamic(){guard let sim=session.simulation else{return};playerNode.position=point(sim.player.position);let walking = sim.player.movementDirection != nil && sim.player.hookshot.phase == .idle;let frame = session.configuration.reducedMotion || !walking ? 0 : Int(sim.player.animationTime / 0.09) % 9;if let t=try? lidiaTexture(sim.player.facing,frame:frame){playerNode.texture=t};let ids=Set(sim.entities.map(\.id));for(id,n)in entityNodes where !ids.contains(id){n.removeFromParent();entityNodes[id]=nil}
        if !session.configuration.reducedMotion { let coinFrame = Int(sim.player.animationTime / 0.08) % 9; for entity in sim.entities where entity.kind == .coin { if let sprite = entityNodes[entity.id] as? SKSpriteNode { sprite.texture = try? loader.texture("goldCoin\(coinFrame + 1).png") } } }
        if sim.chestOpen,let chest=world.childNode(withName:"chest"),let t=try? loader.slice("chests.png",x:291,y:95,width:25,height:29,sheetWidth:512,sheetHeight:512){(chest as? SKSpriteNode)?.texture=t}
        let h=sim.player.hookshot;if h.phase != .idle,let hp=h.head{hook.isHidden=false;chain.isHidden=false;hook.position=point(hp);let path=CGMutablePath();path.move(to:playerNode.position);path.addLine(to:hook.position);chain.path=path}else{hook.isHidden=true;chain.isHidden=true}
    }
    private func layoutWorld(){let side=min(size.width,size.height);cellSize=side/60;boardOrigin=.init(x:(size.width-side)/2,y:(size.height-side)/2);world.setScale(cellSize);world.position=boardOrigin}
    private func showError(_ message:String){removeAllChildren();let box=SKShapeNode(rectOf:.init(width:max(size.width-30,100),height:100),cornerRadius:12);box.fillColor=.systemRed;box.position=.init(x:size.width/2,y:size.height/2);let label=SKLabelNode(text:message);label.fontSize=14;label.numberOfLines=3;label.preferredMaxLayoutWidth=max(size.width-60,80);label.verticalAlignmentMode=.center;box.addChild(label);addChild(box)}
}
