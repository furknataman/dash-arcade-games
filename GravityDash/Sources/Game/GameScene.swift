import SpriteKit
import UIKit
import ArcadeCore

/// Which lane a node lives on.
enum Lane { case floor, ceiling }

/// A scrolling barrier the player must dodge by being on the opposite lane.
final class ObstacleNode: SKShapeNode {
    var lane: Lane = .floor
}

/// GravityDash's only game-specific code: an auto-runner that flips gravity on
/// tap, snapping the player between floor and ceiling to dodge barriers and
/// grab coins. Engine/score/coins/ads/UI come from `ScrollingGameScene`.
final class GravityFlipScene: ScrollingGameScene {

    // Tunables
    private let playerRadius: CGFloat = 18
    private let gravityMagnitude: CGFloat = 34
    private let laneInset: CGFloat = 96
    private let tickSpacing: CGFloat = 48
    private let obstacleWidth: CGFloat = 32
    private let obstacleHeight: CGFloat = 84
    private let coinRadius: CGFloat = 11
    private let minSpawnGap: CGFloat = 300
    private let maxSpawnGap: CGFloat = 470

    // Nodes
    private let player = SKShapeNode(circleOfRadius: 18)
    private let floorLine = SKShapeNode()
    private let ceilLine = SKShapeNode()
    private let boundaries = SKNode()
    private let background = SKSpriteNode()
    private let vignette = SKSpriteNode()
    private var ticks: [SKShapeNode] = []
    private var stars: [(node: SKShapeNode, factor: CGFloat)] = []

    // State
    private var gravityDown = true
    private var spawnAccumulator: CGFloat = 0
    private var nextSpawnGap: CGFloat = 360
    private var obstacles: [ObstacleNode] = []
    private var coins: [SKShapeNode] = []
    private var flipCooldown: TimeInterval = 0
    private var trailAccumulator: CGFloat = 0

    // Tier progression: every `tierStep` points the obstacle + score color
    // advances through this palette, with a flash + haptic for feedback.
    private let tierColors: [RGBA] = [
        RGBA(hex: 0xFF5C6B), RGBA(hex: 0xFF9F40), RGBA(hex: 0xFFD13F),
        RGBA(hex: 0xA8E05F), RGBA(hex: 0x40C4FF), RGBA(hex: 0xB06CF0)
    ]
    private let tierStep: CGFloat = 75
    private var currentTier = -1
    private var currentObstacleColor = RGBA(hex: 0xFF5C6B)

    private var floorY: CGFloat { laneInset }
    private var ceilY: CGFloat { size.height - laneInset }
    private var playerLane: Lane { gravityDown ? .floor : .ceiling }

    // MARK: Build
    override func buildScene() {
        // Depth: gradient backdrop + parallax dust + edge vignette.
        background.zPosition = -20
        addChild(background)

        for i in 0..<40 {
            let near = i % 2 == 0
            let star = SKShapeNode(circleOfRadius: near ? 2.4 : 1.6)
            star.fillColor = SKColor(white: 1, alpha: near ? 0.22 : 0.10)
            star.strokeColor = .clear
            star.zPosition = -10
            stars.append((star, near ? 0.55 : 0.28))
            addChild(star)
        }

        vignette.zPosition = 24
        vignette.alpha = 0.9
        addChild(vignette)

        // Player with a soft glow.
        player.strokeColor = .white
        player.lineWidth = 2
        player.glowWidth = 3
        let body = SKPhysicsBody(circleOfRadius: playerRadius)
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0
        body.linearDamping = 0
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.boundary
        body.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.coin
        player.physicsBody = body
        player.zPosition = 10
        addChild(player)

        for line in [floorLine, ceilLine] {
            line.strokeColor = SKColor(white: 1, alpha: 0.28)
            line.lineWidth = 2
            line.glowWidth = 1
            addChild(line)
        }

        for _ in 0..<40 {
            let tick = SKShapeNode(rectOf: CGSize(width: 4, height: 14), cornerRadius: 2)
            tick.fillColor = SKColor(white: 1, alpha: 0.16)
            tick.strokeColor = .clear
            ticks.append(tick)
            addChild(tick)
        }

        addChild(boundaries)
        applySkin()
    }

    override func layoutScene() {
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.size = size
        background.texture = .verticalGradient(
            size: size,
            top: config.background.lighter(0.05).uiColor,
            bottom: config.background.darker(0.02).uiColor)

        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.size = size
        vignette.texture = .radialVignette(size: size, edge: .black, strength: 0.55)

        for (i, entry) in stars.enumerated() {
            entry.node.position = CGPoint(x: CGFloat(i) * (size.width / 20).rounded(),
                                          y: CGFloat((i * 137) % Int(max(1, size.height))))
        }

        player.position = CGPoint(x: size.width * 0.28, y: floorY + playerRadius)
        floorLine.path = linePath(y: floorY)
        ceilLine.path = linePath(y: ceilY)
        boundaries.removeAllChildren()
        boundaries.addChild(edge(y: floorY))
        boundaries.addChild(edge(y: ceilY))
        layoutTicks()
    }

    // MARK: Run lifecycle
    override func resetRun() {
        obstacles.forEach { $0.removeFromParent() }
        coins.forEach { $0.removeFromParent() }
        obstacles.removeAll()
        coins.removeAll()
        enumerateChildNodes(withName: "trail") { node, _ in node.removeFromParent() }

        gravityDown = true
        physicsWorld.gravity = CGVector(dx: 0, dy: -gravityMagnitude)
        player.zRotation = 0
        player.position = CGPoint(x: size.width * 0.28, y: floorY + playerRadius)
        player.physicsBody?.velocity = .zero
        spawnAccumulator = 0
        nextSpawnGap = maxSpawnGap
        flipCooldown = 0
        trailAccumulator = 0
        currentTier = -1
        currentObstacleColor = config.obstacle
        model?.scoreTint = nil
        applySkin()
    }

    private func applySkin() {
        let color = (config.skin(for: storage.selectedSkinID)?.color ?? config.accent).uiColor
        player.fillColor = color
    }

    // MARK: Input
    override func onPlayTap() {
        gravityDown.toggle()
        physicsWorld.gravity = CGVector(dx: 0, dy: gravityDown ? -gravityMagnitude : gravityMagnitude)
        let spin = SKAction.rotate(byAngle: .pi, duration: 0.18)
        spin.timingMode = .easeOut
        player.run(spin)
        player.physicsBody?.velocity.dy = gravityDown ? -160 : 160
        Haptics.impact(.light, intensity: 0.5)
        audio.play("flip")
    }

    // MARK: Per-frame
    override func tick(dt: CGFloat, advance: CGFloat) {
        // Tier progression (color shift + flash at thresholds).
        let tier = max(0, Int(distance / tierStep))
        if tier != currentTier { applyTier(tier) }

        // Parallax dust.
        let starSpan = size.width
        for (node, factor) in stars {
            node.position.x -= advance * factor
            if node.position.x < -4 { node.position.x += starSpan + 8 }
        }

        let span = CGFloat(ticks.count) * tickSpacing
        for tick in ticks {
            tick.position.x -= advance
            if tick.position.x < -tickSpacing { tick.position.x += span }
        }

        for o in obstacles { o.position.x -= advance }
        for c in coins { c.position.x -= advance }
        obstacles.removeAll { o in
            if o.position.x < -obstacleWidth { o.removeFromParent(); return true }
            return false
        }
        coins.removeAll { c in
            if c.position.x < -coinRadius { c.removeFromParent(); return true }
            return false
        }

        emitTrail(advance: advance)

        spawnAccumulator += advance
        if spawnAccumulator >= nextSpawnGap {
            spawnAccumulator = 0
            nextSpawnGap = CGFloat.random(in: minSpawnGap...maxSpawnGap)
            spawn()
        }
    }

    /// Fading ghost trail behind the player for a sense of speed.
    private func emitTrail(advance: CGFloat) {
        trailAccumulator += advance
        guard trailAccumulator >= 16 else { return }
        trailAccumulator = 0
        let ghost = SKShapeNode(circleOfRadius: playerRadius * 0.82)
        ghost.fillColor = player.fillColor
        ghost.strokeColor = .clear
        ghost.alpha = 0.35
        ghost.position = player.position
        ghost.zPosition = 9
        ghost.name = "trail"
        addChild(ghost)
        ghost.run(.sequence([
            .group([.fadeOut(withDuration: 0.32), .scale(to: 0.3, duration: 0.32)]),
            .removeFromParent()
        ]))
    }

    // MARK: Spawning
    private func spawn() {
        let lane: Lane = Bool.random() ? .floor : .ceiling
        let x = size.width + obstacleWidth
        let obstacle = ObstacleNode()
        obstacle.path = CGPath(roundedRect: CGRect(x: -obstacleWidth / 2, y: -obstacleHeight / 2,
                                                   width: obstacleWidth, height: obstacleHeight),
                               cornerWidth: 8, cornerHeight: 8, transform: nil)
        obstacle.fillColor = currentObstacleColor.uiColor
        obstacle.strokeColor = currentObstacleColor.lighter(0.18).uiColor
        obstacle.lineWidth = 2
        obstacle.glowWidth = 3
        obstacle.lane = lane
        obstacle.position = CGPoint(x: x, y: laneY(lane, offset: obstacleHeight / 2))
        let obody = SKPhysicsBody(rectangleOf: CGSize(width: obstacleWidth, height: obstacleHeight))
        obody.isDynamic = false
        obody.categoryBitMask = PhysicsCategory.obstacle
        obody.collisionBitMask = 0
        obstacle.physicsBody = obody
        obstacle.zPosition = 5
        addChild(obstacle)
        obstacles.append(obstacle)

        if Bool.random() {
            let opposite: Lane = (lane == .floor) ? .ceiling : .floor
            let y = laneY(opposite, offset: playerRadius)
            for i in 0..<3 {
                let coin = SKShapeNode(circleOfRadius: coinRadius)
                coin.fillColor = config.coin.uiColor
                coin.strokeColor = config.coin.lighter(0.25).uiColor
                coin.lineWidth = 2
                coin.glowWidth = 4
                coin.position = CGPoint(x: x + CGFloat(i) * 34, y: y)
                let cbody = SKPhysicsBody(circleOfRadius: coinRadius)
                cbody.isDynamic = false
                cbody.categoryBitMask = PhysicsCategory.coin
                cbody.collisionBitMask = 0
                coin.physicsBody = cbody
                coin.zPosition = 4
                coin.run(.repeatForever(.sequence([
                    .scale(to: 1.18, duration: 0.5),
                    .scale(to: 1.0, duration: 0.5)
                ])))
                addChild(coin)
                coins.append(coin)
            }
        }
    }

    /// Cross into a new color tier. Kept moderate: a gentle obstacle + score
    /// color shift and a soft haptic — no full-screen flash, no shake.
    private func applyTier(_ tier: Int) {
        currentTier = tier
        let color = tierColors[tier % tierColors.count]
        currentObstacleColor = color
        if tier == 0 {
            model?.scoreTint = nil
        } else {
            model?.scoreTint = color
            Haptics.impact(.light, intensity: 0.5)
        }
    }

    private func laneY(_ lane: Lane, offset: CGFloat) -> CGFloat {
        switch lane {
        case .floor:   return floorY + offset
        case .ceiling: return ceilY - offset
        }
    }

    // MARK: Contacts
    override func handleContact(_ contact: SKPhysicsContact) {
        let other = (contact.bodyA.categoryBitMask == PhysicsCategory.player)
            ? contact.bodyB : contact.bodyA
        switch other.categoryBitMask {
        case PhysicsCategory.obstacle:
            killPlayer()
        case PhysicsCategory.coin:
            if let coin = other.node as? SKShapeNode {
                coins.removeAll { $0 === coin }
                coin.physicsBody = nil
                let point = coin.position
                coin.vanish()
                collectCoin(at: point)
            }
        default:
            break
        }
    }

    // MARK: Revive
    override func clearHazardsForRevive() {
        let safeRange: CGFloat = 240
        obstacles.removeAll { o in
            if abs(o.position.x - player.position.x) < safeRange {
                o.removeFromParent(); return true
            }
            return false
        }
        player.physicsBody?.velocity = .zero
    }

    // MARK: Auto-pilot (verification only)
    override func autoPilot(dt: CGFloat) {
        flipCooldown -= dt
        guard flipCooldown <= 0 else { return }
        let reactMin: CGFloat = 30
        let reactMax: CGFloat = 210
        var nearest: ObstacleNode?
        var nearestDx = CGFloat.greatestFiniteMagnitude
        for o in obstacles {
            let dx = o.position.x - player.position.x
            if dx > reactMin && dx < reactMax && dx < nearestDx {
                nearest = o
                nearestDx = dx
            }
        }
        if let o = nearest, o.lane == playerLane {
            onPlayTap()
            flipCooldown = 0.28
        }
    }

    // MARK: Helpers
    private func linePath(y: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: y))
        p.addLine(to: CGPoint(x: size.width, y: y))
        return p
    }

    private func edge(y: CGFloat) -> SKNode {
        let node = SKNode()
        let body = SKPhysicsBody(edgeFrom: CGPoint(x: -200, y: y),
                                 to: CGPoint(x: size.width + 200, y: y))
        body.categoryBitMask = PhysicsCategory.boundary
        body.friction = 0
        body.restitution = 0
        node.physicsBody = body
        return node
    }

    private func layoutTicks() {
        for (i, tick) in ticks.enumerated() {
            tick.position = CGPoint(x: CGFloat(i) * tickSpacing, y: floorY - 16)
        }
    }
}
