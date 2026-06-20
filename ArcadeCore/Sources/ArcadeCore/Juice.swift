import SpriteKit

/// Reusable "game feel" helpers. Juice is what separates a prototype from a
/// game people replay, so every game gets these for free.

public extension SKNode {
    /// Quick squash-and-stretch pop, e.g. when collecting a coin.
    func popScale(to: CGFloat = 1.35, duration: TimeInterval = 0.12) {
        removeAction(forKey: "pop")
        let up = SKAction.scale(to: to, duration: duration / 2)
        up.timingMode = .easeOut
        let down = SKAction.scale(to: 1.0, duration: duration / 2)
        down.timingMode = .easeIn
        run(.sequence([up, down]), withKey: "pop")
    }

    /// Fade + scale out then remove. Good for collected pickups.
    func vanish(duration: TimeInterval = 0.14) {
        run(.sequence([
            .group([.scale(to: 1.7, duration: duration), .fadeOut(withDuration: duration)]),
            .removeFromParent()
        ]))
    }
}

public extension SKScene {
    /// Camera-based screen shake. Requires the scene to use an `SKCameraNode`
    /// (ScrollingGameScene sets one up). Returns the camera to its rest spot.
    func screenShake(intensity: CGFloat = 10, duration: TimeInterval = 0.3) {
        guard let cam = camera else { return }
        let steps = 6
        var actions: [SKAction] = []
        for i in 0..<steps {
            let falloff = 1 - CGFloat(i) / CGFloat(steps)
            let dx = (i % 2 == 0 ? intensity : -intensity) * falloff
            let dy = (i % 2 == 0 ? -intensity : intensity) * falloff * 0.7
            let move = SKAction.moveBy(x: dx, y: dy, duration: duration / Double(steps * 2))
            move.timingMode = .easeInEaseOut
            actions.append(move)
            actions.append(move.reversed())
        }
        cam.run(.sequence(actions), withKey: "shake")
    }

    /// Radial particle burst built from cheap shape nodes (no asset needed).
    func emitBurst(at point: CGPoint,
                   color: SKColor,
                   count: Int = 12,
                   speed: CGFloat = 140,
                   radius: CGFloat = 3,
                   into parent: SKNode? = nil) {
        let host = parent ?? self
        for i in 0..<count {
            let p = SKShapeNode(circleOfRadius: radius)
            p.fillColor = color
            p.strokeColor = .clear
            p.position = point
            p.zPosition = 50
            host.addChild(p)
            let angle = (CGFloat(i) / CGFloat(count)) * .pi * 2 + CGFloat.random(in: -0.2...0.2)
            let dist = speed * CGFloat.random(in: 0.5...1.0)
            let move = SKAction.moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 0.45)
            move.timingMode = .easeOut
            p.run(.sequence([
                .group([move, .fadeOut(withDuration: 0.45), .scale(to: 0.2, duration: 0.45)]),
                .removeFromParent()
            ]))
        }
    }
}
