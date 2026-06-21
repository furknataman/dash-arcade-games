import SpriteKit
import UIKit
import ArcadeCore

/// A vertical pair of pipes with a gap the bird must fly through.
private final class Pipe {
    let top: SKShapeNode
    let bottom: SKShapeNode
    let gapCenterY: CGFloat
    var coin: SKShapeNode?
    init(top: SKShapeNode, bottom: SKShapeNode, gapCenterY: CGFloat) {
        self.top = top; self.bottom = bottom; self.gapCenterY = gapCenterY
    }
}

/// FlapDash: tap to flap upward, fall with gravity, thread the gaps. All
/// engine/score/coins/ads/UI come from `ScrollingGameScene` (ArcadeCore).
final class FlapScene: ScrollingGameScene {

    // Tunables
    private let birdRadius: CGFloat = 16
    private let gravityMagnitude: CGFloat = 42
    private let flapVelocity: CGFloat = 520
    private let pipeWidth: CGFloat = 72
    private let gapHeight: CGFloat = 210
    private let groundHeight: CGFloat = 70
    private let minSpawnGap: CGFloat = 230
    private let maxSpawnGap: CGFloat = 300

    // Nodes
    private let bird = SKShapeNode(circleOfRadius: 16)
    private let background = SKSpriteNode()
    private let vignette = SKSpriteNode()
    private let ground = SKShapeNode()
    private var stars: [(node: SKShapeNode, factor: CGFloat)] = []

    // State
    private var pipes: [Pipe] = []
    private var spawnAccumulator: CGFloat = 0
    private var nextSpawnGap: CGFloat = 260
    private var flapCooldown: TimeInterval = 0
    private var trailAccumulator: CGFloat = 0

    // Tiers (pipe + score color shift)
    private let tierColors: [RGBA] = [
        RGBA(hex: 0x49C628), RGBA(hex: 0x40C4FF), RGBA(hex: 0xB06CF0),
        RGBA(hex: 0xFF9F40), RGBA(hex: 0xFF5C6B), RGBA(hex: 0xFFD13F)
    ]
    private let tierStep: CGFloat = 60
    private var currentTier = -1
    private var pipeColor = RGBA(hex: 0x49C628)

    private var groundY: CGFloat { groundHeight }

    // MARK: Build
    override func buildScene() {
        background.zPosition = -20
        addChild(background)

        for i in 0..<36 {
            let near = i % 2 == 0
            let s = SKShapeNode(circleOfRadius: near ? 2.2 : 1.5)
            s.fillColor = SKColor(white: 1, alpha: near ? 0.20 : 0.09)
            s.strokeColor = .clear
            s.zPosition = -10
            stars.append((s, near ? 0.5 : 0.25))
            addChild(s)
        }

        vignette.zPosition = 24
        vignette.alpha = 0.9
        addChild(vignette)

        ground.fillColor = SKColor(white: 1, alpha: 0.10)
        ground.strokeColor = SKColor(white: 1, alpha: 0.25)
        ground.lineWidth = 2
        ground.zPosition = 6
        addChild(ground)

        bird.strokeColor = .white
        bird.lineWidth = 2
        bird.glowWidth = 3
        let body = SKPhysicsBody(circleOfRadius: birdRadius)
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.boundary       // bonk the ceiling, don't die
        body.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.coin
        bird.physicsBody = body
        bird.zPosition = 10
        addChild(bird)

        applySkin()
    }

    override func layoutScene() {
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.size = size
        background.texture = .verticalGradient(
            size: size,
            top: config.background.lighter(0.06).uiColor,
            bottom: config.background.darker(0.02).uiColor)
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.size = size
        vignette.texture = .radialVignette(size: size, edge: .black, strength: 0.5)

        for (i, e) in stars.enumerated() {
            e.node.position = CGPoint(x: CGFloat(i) * (size.width / 18).rounded(),
                                      y: CGFloat((i * 151) % Int(max(1, size.height))))
        }

        ground.path = CGPath(rect: CGRect(x: 0, y: 0, width: size.width, height: groundHeight), transform: nil)

        // Ceiling boundary (bonk) + lethal ground edge.
        physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: size.height),
                                    to: CGPoint(x: size.width, y: size.height))
        physicsBody?.categoryBitMask = PhysicsCategory.boundary

        // ground death edge as a child node
        childNode(withName: "groundEdge")?.removeFromParent()
        let ge = SKNode(); ge.name = "groundEdge"
        let gb = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: groundY), to: CGPoint(x: size.width, y: groundY))
        gb.categoryBitMask = PhysicsCategory.obstacle
        gb.collisionBitMask = 0
        ge.physicsBody = gb
        addChild(ge)

        bird.position = CGPoint(x: size.width * 0.3, y: size.height * 0.6)
    }

    // MARK: Run lifecycle
    override func resetRun() {
        pipes.forEach { $0.top.removeFromParent(); $0.bottom.removeFromParent(); $0.coin?.removeFromParent() }
        pipes.removeAll()
        enumerateChildNodes(withName: "trail") { n, _ in n.removeFromParent() }

        physicsWorld.gravity = .zero          // float until first flap
        bird.position = CGPoint(x: size.width * 0.3, y: size.height * 0.6)
        bird.physicsBody?.velocity = .zero
        bird.zRotation = 0
        spawnAccumulator = 0
        nextSpawnGap = maxSpawnGap
        flapCooldown = 0
        trailAccumulator = 0
        currentTier = -1
        pipeColor = config.obstacle
        model?.scoreTint = nil
        applySkin()
    }

    override func didStartRun() {
        physicsWorld.gravity = CGVector(dx: 0, dy: -gravityMagnitude)
        flap()
    }

    private func applySkin() {
        bird.fillColor = (config.skin(for: storage.selectedSkinID)?.color ?? config.accent).uiColor
    }

    // MARK: Input
    override func onPlayTap() { flap() }

    private func flap() {
        bird.physicsBody?.velocity.dy = flapVelocity
        Haptics.impact(.light, intensity: 0.5)
        audio.play("flap")
        bird.removeAction(forKey: "tilt")
        bird.run(.sequence([.rotate(toAngle: 0.35, duration: 0.08),
                            .rotate(toAngle: -0.25, duration: 0.5)]), withKey: "tilt")
    }

    // MARK: Per-frame
    override func tick(dt: CGFloat, advance: CGFloat) {
        let tier = max(0, Int(distance / tierStep))
        if tier != currentTier { applyTier(tier) }

        for (node, factor) in stars {
            node.position.x -= advance * factor
            if node.position.x < -4 { node.position.x += size.width + 8 }
        }

        for p in pipes {
            p.top.position.x -= advance
            p.bottom.position.x -= advance
            p.coin?.position.x -= advance
        }
        pipes.removeAll { p in
            if p.top.position.x < -pipeWidth {
                p.top.removeFromParent(); p.bottom.removeFromParent(); p.coin?.removeFromParent()
                return true
            }
            return false
        }

        // Dip the bird's nose as it falls.
        if let vy = bird.physicsBody?.velocity.dy, vy < -40 {
            bird.zRotation = max(-0.6, bird.zRotation - 2.4 * dt)
        }

        emitTrail(advance: advance)

        spawnAccumulator += advance
        if spawnAccumulator >= nextSpawnGap {
            spawnAccumulator = 0
            nextSpawnGap = CGFloat.random(in: minSpawnGap...maxSpawnGap)
            spawn()
        }
    }

    private func emitTrail(advance: CGFloat) {
        trailAccumulator += advance
        guard trailAccumulator >= 14 else { return }
        trailAccumulator = 0
        let g = SKShapeNode(circleOfRadius: birdRadius * 0.8)
        g.fillColor = bird.fillColor; g.strokeColor = .clear; g.alpha = 0.3
        g.position = bird.position; g.zPosition = 9; g.name = "trail"
        addChild(g)
        g.run(.sequence([.group([.fadeOut(withDuration: 0.3), .scale(to: 0.3, duration: 0.3)]), .removeFromParent()]))
    }

    // MARK: Spawning
    private func spawn() {
        let margin: CGFloat = 70
        let minC = groundY + margin + gapHeight / 2
        let maxC = size.height - margin - gapHeight / 2
        let gapCenter = CGFloat.random(in: minC...maxC)
        let x = size.width + pipeWidth

        let topH = size.height - (gapCenter + gapHeight / 2)
        let botH = (gapCenter - gapHeight / 2) - groundY
        let top = makePipe(height: topH)
        top.position = CGPoint(x: x, y: size.height - topH / 2)
        let bottom = makePipe(height: botH)
        bottom.position = CGPoint(x: x, y: groundY + botH / 2)
        addChild(top); addChild(bottom)

        let pipe = Pipe(top: top, bottom: bottom, gapCenterY: gapCenter)

        if Bool.random() {
            let coin = SKShapeNode(circleOfRadius: 11)
            coin.fillColor = config.coin.uiColor
            coin.strokeColor = config.coin.lighter(0.25).uiColor
            coin.lineWidth = 2
            coin.glowWidth = 4
            coin.position = CGPoint(x: x, y: gapCenter)
            let cb = SKPhysicsBody(circleOfRadius: 11)
            cb.isDynamic = false
            cb.categoryBitMask = PhysicsCategory.coin
            cb.collisionBitMask = 0
            coin.physicsBody = cb
            coin.zPosition = 4
            coin.run(.repeatForever(.sequence([.scale(to: 1.18, duration: 0.5), .scale(to: 1.0, duration: 0.5)])))
            addChild(coin)
            pipe.coin = coin
        }
        pipes.append(pipe)
    }

    private func makePipe(height: CGFloat) -> SKShapeNode {
        let h = max(8, height)
        let node = SKShapeNode(rect: CGRect(x: -pipeWidth / 2, y: -h / 2, width: pipeWidth, height: h), cornerRadius: 10)
        node.fillColor = pipeColor.uiColor
        node.strokeColor = pipeColor.lighter(0.18).uiColor
        node.lineWidth = 2
        node.glowWidth = 2
        node.zPosition = 5
        let b = SKPhysicsBody(rectangleOf: CGSize(width: pipeWidth, height: h))
        b.isDynamic = false
        b.categoryBitMask = PhysicsCategory.obstacle
        b.collisionBitMask = 0
        node.physicsBody = b
        return node
    }

    // MARK: Contacts
    override func handleContact(_ contact: SKPhysicsContact) {
        let other = (contact.bodyA.categoryBitMask == PhysicsCategory.player) ? contact.bodyB : contact.bodyA
        switch other.categoryBitMask {
        case PhysicsCategory.obstacle:
            killPlayer()
        case PhysicsCategory.coin:
            if let coin = other.node as? SKShapeNode {
                for p in pipes where p.coin === coin { p.coin = nil }
                coin.physicsBody = nil
                let pt = coin.position
                coin.vanish()
                collectCoin(at: pt)
            }
        default: break
        }
    }

    // MARK: Revive
    override func clearHazardsForRevive() {
        let safe: CGFloat = 260
        pipes.removeAll { p in
            if abs(p.top.position.x - bird.position.x) < safe {
                p.top.removeFromParent(); p.bottom.removeFromParent(); p.coin?.removeFromParent()
                return true
            }
            return false
        }
        bird.position = CGPoint(x: size.width * 0.3, y: size.height * 0.6)
        bird.physicsBody?.velocity = .zero
    }

    // MARK: Auto-pilot
    override func autoPilot(dt: CGFloat) {
        flapCooldown -= dt
        guard flapCooldown <= 0 else { return }
        // Target the gap of the nearest pipe ahead (or stay centered).
        var targetY = size.height * 0.55
        var nearestDx = CGFloat.greatestFiniteMagnitude
        for p in pipes {
            let dx = p.top.position.x - bird.position.x
            if dx > -pipeWidth && dx < 260 && dx < nearestDx {
                nearestDx = dx; targetY = p.gapCenterY
            }
        }
        let vy = bird.physicsBody?.velocity.dy ?? 0
        if bird.position.y < targetY - 6 && vy < 120 {
            flap()
            flapCooldown = 0.18
        }
    }

    // MARK: Tier
    /// Moderate tier shift: gentle pipe + score color change, soft haptic only.
    private func applyTier(_ tier: Int) {
        currentTier = tier
        let c = tierColors[tier % tierColors.count]
        pipeColor = c
        if tier == 0 {
            model?.scoreTint = nil
        } else {
            model?.scoreTint = c
            Haptics.impact(.light, intensity: 0.5)
        }
    }
}
