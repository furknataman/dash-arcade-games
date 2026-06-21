import SpriteKit
import UIKit
import ArcadeCore

/// A ground block the runner must jump over.
final class Hurdle: SKShapeNode {}

/// JumpDash: an endless runner. Tap to jump over hurdles, collect coins.
/// Engine/score/coins/ads/UI all come from `ScrollingGameScene` (ArcadeCore).
final class JumpScene: ScrollingGameScene {

    // Tunables
    private let playerSize: CGFloat = 38
    private let gravityMagnitude: CGFloat = 60
    private let jumpVelocity: CGFloat = 840
    private let groundHeight: CGFloat = 120
    private let minSpawnGap: CGFloat = 280
    private let maxSpawnGap: CGFloat = 430

    // Nodes
    private let player = SKShapeNode()
    private let background = SKSpriteNode()
    private let vignette = SKSpriteNode()
    private let ground = SKShapeNode()
    private var stars: [(node: SKShapeNode, factor: CGFloat)] = []

    // State
    private var hurdles: [Hurdle] = []
    private var coins: [SKShapeNode] = []
    private var spawnAccumulator: CGFloat = 0
    private var nextSpawnGap: CGFloat = 320
    private var trailAccumulator: CGFloat = 0

    // Tiers
    private let tierColors: [RGBA] = [
        RGBA(hex: 0x1B1330), RGBA(hex: 0x2A1745), RGBA(hex: 0x3A1A55),
        RGBA(hex: 0x14283A), RGBA(hex: 0x102A2A), RGBA(hex: 0x301038)
    ]
    private let hurdleColors: [RGBA] = [
        RGBA(hex: 0xFF5C8A), RGBA(hex: 0xFFA63F), RGBA(hex: 0x49E0C0),
        RGBA(hex: 0x6CC0FF), RGBA(hex: 0xC58BFF), RGBA(hex: 0xFFE08A)
    ]
    private let tierStep: CGFloat = 75
    private var currentTier = -1
    private var hurdleColor = RGBA(hex: 0xFF5C8A)

    private var groundY: CGFloat { groundHeight }
    private var restY: CGFloat { groundY + playerSize / 2 }
    private var isGrounded: Bool {
        (player.position.y <= restY + 6) && ((player.physicsBody?.velocity.dy ?? 0) <= 1)
    }

    // MARK: Build
    override func buildScene() {
        background.zPosition = -20
        addChild(background)

        for i in 0..<32 {
            let near = i % 2 == 0
            let s = SKShapeNode(circleOfRadius: near ? 2.0 : 1.4)
            s.fillColor = SKColor(white: 1, alpha: near ? 0.16 : 0.07)
            s.strokeColor = .clear
            s.zPosition = -10
            stars.append((s, near ? 0.45 : 0.22))
            addChild(s)
        }

        vignette.zPosition = 24
        vignette.alpha = 0.9
        addChild(vignette)

        ground.fillColor = SKColor(white: 1, alpha: 0.08)
        ground.strokeColor = SKColor(white: 1, alpha: 0.30)
        ground.lineWidth = 2
        ground.zPosition = 6
        addChild(ground)

        let rect = CGRect(x: -playerSize / 2, y: -playerSize / 2, width: playerSize, height: playerSize)
        player.path = CGPath(roundedRect: rect, cornerWidth: 9, cornerHeight: 9, transform: nil)
        player.strokeColor = .white
        player.lineWidth = 2
        player.glowWidth = 3
        let body = SKPhysicsBody(rectangleOf: CGSize(width: playerSize, height: playerSize))
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.boundary       // rest on the ground
        body.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.coin
        player.physicsBody = body
        player.zPosition = 10
        addChild(player)

        applySkin()
    }

    override func layoutScene() {
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.size = size
        background.texture = .verticalGradient(
            size: size,
            top: config.background.lighter(0.08).uiColor,
            bottom: config.background.darker(0.03).uiColor)
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.size = size
        vignette.texture = .radialVignette(size: size, edge: .black, strength: 0.5)

        for (i, e) in stars.enumerated() {
            e.node.position = CGPoint(x: CGFloat(i) * (size.width / 16).rounded(),
                                      y: groundY + CGFloat((i * 53) % Int(max(1, size.height - groundY))))
        }

        ground.path = CGPath(rect: CGRect(x: 0, y: 0, width: size.width, height: groundHeight), transform: nil)

        childNode(withName: "groundEdge")?.removeFromParent()
        let ge = SKNode(); ge.name = "groundEdge"
        let gb = SKPhysicsBody(edgeFrom: CGPoint(x: -200, y: groundY), to: CGPoint(x: size.width + 200, y: groundY))
        gb.categoryBitMask = PhysicsCategory.boundary
        gb.friction = 0
        ge.physicsBody = gb
        addChild(ge)

        player.position = CGPoint(x: size.width * 0.26, y: restY)
    }

    // MARK: Run lifecycle
    override func resetRun() {
        hurdles.forEach { $0.removeFromParent() }
        coins.forEach { $0.removeFromParent() }
        hurdles.removeAll(); coins.removeAll()
        enumerateChildNodes(withName: "trail") { n, _ in n.removeFromParent() }

        physicsWorld.gravity = CGVector(dx: 0, dy: -gravityMagnitude)
        player.position = CGPoint(x: size.width * 0.26, y: restY)
        player.physicsBody?.velocity = .zero
        spawnAccumulator = 0
        nextSpawnGap = maxSpawnGap
        trailAccumulator = 0
        currentTier = -1
        hurdleColor = hurdleColors[0]
        model?.scoreTint = nil
        applySkin()
    }

    private func applySkin() {
        player.fillColor = (config.skin(for: storage.selectedSkinID)?.color ?? config.accent).uiColor
    }

    // MARK: Input
    override func onPlayTap() {
        guard isGrounded else { return }
        player.physicsBody?.velocity.dy = jumpVelocity
        Haptics.impact(.medium, intensity: 0.7)
        audio.play("jump")
        player.removeAction(forKey: "squash")
        player.run(.sequence([.scaleX(to: 0.85, y: 1.18, duration: 0.1),
                              .scale(to: 1.0, duration: 0.16)]), withKey: "squash")
    }

    // MARK: Per-frame
    override func tick(dt: CGFloat, advance: CGFloat) {
        let tier = max(0, Int(distance / tierStep))
        if tier != currentTier { applyTier(tier) }

        for (node, factor) in stars {
            node.position.x -= advance * factor
            if node.position.x < -4 { node.position.x += size.width + 8 }
        }

        for h in hurdles { h.position.x -= advance }
        for c in coins { c.position.x -= advance }
        hurdles.removeAll { h in
            if h.position.x < -60 { h.removeFromParent(); return true }
            return false
        }
        coins.removeAll { c in
            if c.position.x < -16 { c.removeFromParent(); return true }
            return false
        }

        // little spin in the air for juice
        if !isGrounded { player.zRotation -= 3.0 * dt } else { player.zRotation = 0 }

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
        guard trailAccumulator >= 16, !isGrounded else { return }
        trailAccumulator = 0
        let g = SKShapeNode(rectOf: CGSize(width: playerSize * 0.8, height: playerSize * 0.8), cornerRadius: 8)
        g.fillColor = player.fillColor; g.strokeColor = .clear; g.alpha = 0.3
        g.position = player.position; g.zPosition = 9; g.name = "trail"
        addChild(g)
        g.run(.sequence([.group([.fadeOut(withDuration: 0.3), .scale(to: 0.3, duration: 0.3)]), .removeFromParent()]))
    }

    // MARK: Spawning
    private func spawn() {
        let h = CGFloat.random(in: 40...96)
        let x = size.width + 40
        let hurdle = Hurdle(rect: CGRect(x: -18, y: 0, width: 36, height: h), cornerRadius: 7)
        hurdle.fillColor = hurdleColor.uiColor
        hurdle.strokeColor = hurdleColor.lighter(0.2).uiColor
        hurdle.lineWidth = 2
        hurdle.glowWidth = 2
        hurdle.position = CGPoint(x: x, y: groundY)
        let b = SKPhysicsBody(rectangleOf: CGSize(width: 36, height: h), center: CGPoint(x: 0, y: h / 2))
        b.isDynamic = false
        b.categoryBitMask = PhysicsCategory.obstacle
        b.collisionBitMask = 0
        hurdle.physicsBody = b
        hurdle.zPosition = 5
        addChild(hurdle)
        hurdles.append(hurdle)

        // a coin floating at jump height past the hurdle
        if Bool.random() {
            let coin = SKShapeNode(circleOfRadius: 11)
            coin.fillColor = config.coin.uiColor
            coin.strokeColor = config.coin.lighter(0.25).uiColor
            coin.lineWidth = 2
            coin.glowWidth = 4
            coin.position = CGPoint(x: x + 90, y: groundY + 120)
            let cb = SKPhysicsBody(circleOfRadius: 11)
            cb.isDynamic = false
            cb.categoryBitMask = PhysicsCategory.coin
            cb.collisionBitMask = 0
            coin.physicsBody = cb
            coin.zPosition = 4
            coin.run(.repeatForever(.sequence([.scale(to: 1.18, duration: 0.5), .scale(to: 1.0, duration: 0.5)])))
            addChild(coin)
            coins.append(coin)
        }
    }

    // MARK: Contacts
    override func handleContact(_ contact: SKPhysicsContact) {
        let other = (contact.bodyA.categoryBitMask == PhysicsCategory.player) ? contact.bodyB : contact.bodyA
        switch other.categoryBitMask {
        case PhysicsCategory.obstacle:
            killPlayer()
        case PhysicsCategory.coin:
            if let coin = other.node as? SKShapeNode {
                coins.removeAll { $0 === coin }
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
        let safe: CGFloat = 280
        hurdles.removeAll { h in
            if abs(h.position.x - player.position.x) < safe {
                h.removeFromParent(); return true
            }
            return false
        }
        player.position = CGPoint(x: size.width * 0.26, y: restY)
        player.physicsBody?.velocity = .zero
    }

    // MARK: Auto-pilot
    override func autoPilot(dt: CGFloat) {
        guard isGrounded else { return }
        for h in hurdles {
            let dx = h.position.x - player.position.x
            if dx > 30 && dx < 150 {
                onPlayTap()
                break
            }
        }
    }

    // MARK: Tier
    /// Moderate tier shift: a gentle background-gradient flow (this game's
    /// signature) plus a soft hurdle + score color change. No flash, no shake.
    private func applyTier(_ tier: Int) {
        currentTier = tier
        hurdleColor = hurdleColors[tier % hurdleColors.count]
        let bg = tierColors[tier % tierColors.count]
        let fade = SKAction.customAction(withDuration: 0.6) { [weak self] _, _ in
            guard let self else { return }
            self.background.texture = .verticalGradient(
                size: self.size, top: bg.lighter(0.08).uiColor, bottom: bg.darker(0.03).uiColor)
        }
        background.run(fade)
        model?.scoreTint = (tier == 0) ? nil : hurdleColor
        if tier > 0 { Haptics.impact(.light, intensity: 0.5) }
    }
}
