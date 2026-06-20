import SpriteKit
import UIKit

/// Cheap, reusable backdrop textures so every game gets depth without art assets.
public extension SKTexture {

    /// A smooth vertical gradient.
    static func verticalGradient(size: CGSize, top: UIColor, bottom: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [top.cgColor, bottom.cgColor] as CFArray,
                                  locations: [0, 1])!
            cg.drawLinearGradient(grad,
                                  start: CGPoint(x: size.width / 2, y: 0),
                                  end: CGPoint(x: size.width / 2, y: size.height),
                                  options: [])
        }
        return SKTexture(image: image)
    }

    /// A radial vignette: transparent in the middle, `edge`-colored at the corners.
    static func radialVignette(size: CGSize, edge: UIColor, strength: CGFloat = 0.5) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(size.width, size.height) * 0.72
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [edge.withAlphaComponent(0).cgColor,
                                           edge.withAlphaComponent(strength).cgColor] as CFArray,
                                  locations: [0.55, 1])!
            cg.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                                  endCenter: center, endRadius: radius, options: [])
        }
        return SKTexture(image: image)
    }
}
