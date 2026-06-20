import Foundation
import Combine

public enum GamePhase: Equatable {
    case ready      // pre-game menu / "tap to start"
    case playing
    case paused
    case dead       // game over screen
}

/// The bridge between the SpriteKit scene and the SwiftUI overlays.
///
/// The scene WRITES live state (phase/score/coins) onto this object so SwiftUI
/// re-renders the right overlay. SwiftUI buttons CALL the command closures,
/// which the scene assigns in `didMove`. This keeps the two worlds decoupled
/// with no polling.
@MainActor
public final class GameModel: ObservableObject {
    @Published public var phase: GamePhase = .ready
    @Published public var score: Int = 0
    @Published public var bestScore: Int = 0
    @Published public var runCoins: Int = 0
    @Published public var totalCoins: Int = 0
    @Published public var canRevive: Bool = true
    @Published public var coinsDoubled: Bool = false
    @Published public var newBest: Bool = false
    @Published public var showShop: Bool = false
    /// Tint for the HUD score; games update it as the player crosses tiers.
    @Published public var scoreTint: RGBA? = nil

    // Commands wired by the scene (default no-ops).
    public var startTapped: () -> Void = {}
    public var flipTapped: () -> Void = {}
    public var reviveTapped: () -> Void = {}
    public var doubleCoinsTapped: () -> Void = {}
    public var restartTapped: () -> Void = {}
    public var homeTapped: () -> Void = {}
    public var pauseTapped: () -> Void = {}
    public var resumeTapped: () -> Void = {}

    public init() {}
}
