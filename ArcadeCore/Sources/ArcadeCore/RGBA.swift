import UIKit

/// Lightweight, value-type color used across SpriteKit (UIColor) and SwiftUI.
/// Keeping colors as plain components lets the core avoid importing SwiftUI
/// in model code while still feeding both rendering layers.
public struct RGBA: Equatable, Hashable, Codable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// Init from a 0xRRGGBB hex literal.
    public init(hex: UInt32, alpha: Double = 1) {
        self.r = Double((hex >> 16) & 0xFF) / 255.0
        self.g = Double((hex >> 8) & 0xFF) / 255.0
        self.b = Double(hex & 0xFF) / 255.0
        self.a = alpha
    }

    public var uiColor: UIColor {
        UIColor(red: r, green: g, blue: b, alpha: a)
    }

    public func lighter(_ amount: Double = 0.2) -> RGBA {
        RGBA(min(1, r + amount), min(1, g + amount), min(1, b + amount), a)
    }

    public func darker(_ amount: Double = 0.2) -> RGBA {
        RGBA(max(0, r - amount), max(0, g - amount), max(0, b - amount), a)
    }
}
