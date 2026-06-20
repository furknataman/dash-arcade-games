import Foundation

/// A cosmetic the player can unlock with coins (or that ships unlocked).
/// Games define their own skin list in `GameConfig`.
public struct Skin: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let color: RGBA
    /// Coin price. 0 means it ships unlocked.
    public let price: Int

    public init(id: String, name: String, color: RGBA, price: Int) {
        self.id = id
        self.name = name
        self.color = color
        self.price = price
    }
}
