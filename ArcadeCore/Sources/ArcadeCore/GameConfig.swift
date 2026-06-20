import CoreGraphics
import Foundation

/// Everything that makes one ArcadeCore game different from another: its name,
/// palette, tuning, cosmetics and monetization product ids. A new game is, in
/// large part, just a new `GameConfig` + a `ScrollingGameScene` subclass.
public struct GameConfig {
    // Identity
    public var displayName: String
    public var storageNamespace: String
    /// Short tagline under the title. Treated as a localization key.
    public var tagline: String

    // Tuning
    public var baseSpeed: CGFloat
    public var maxSpeed: CGFloat
    public var speedRamp: CGFloat           // points/sec added per second alive
    public var scoreRate: CGFloat           // score units per point scrolled

    // Palette
    public var background: RGBA
    public var accent: RGBA
    public var obstacle: RGBA
    public var coin: RGBA

    // Cosmetics & monetization
    public var skins: [Skin]
    public var removeAdsProductID: String
    public var coinPackProductIDs: [String]
    public var interstitialEveryDeaths: Int
    /// AdMob rewarded/interstitial unit ids. Default to Google's public TEST
    /// ids so the game is fully playable before real ids exist; swap for your
    /// real ids (and the GADApplicationIdentifier in Info.plist) before launch.
    public var rewardedAdUnitID: String
    public var interstitialAdUnitID: String
    /// Game Center leaderboard id (created in App Store Connect). nil disables it.
    public var leaderboardID: String?

    public init(
        displayName: String,
        storageNamespace: String,
        tagline: String = "TAP TO PLAY",
        baseSpeed: CGFloat = 320,
        maxSpeed: CGFloat = 640,
        speedRamp: CGFloat = 7,
        scoreRate: CGFloat = 0.1,
        background: RGBA = RGBA(hex: 0x0D0F1E),
        accent: RGBA = RGBA(hex: 0x40E5D9),
        obstacle: RGBA = RGBA(hex: 0xFF5C6B),
        coin: RGBA = RGBA(hex: 0xFFD13F),
        skins: [Skin] = [],
        removeAdsProductID: String,
        coinPackProductIDs: [String] = [],
        interstitialEveryDeaths: Int = 3,
        rewardedAdUnitID: String = "ca-app-pub-3940256099942544/1712485313",
        interstitialAdUnitID: String = "ca-app-pub-3940256099942544/4411468910",
        leaderboardID: String? = nil
    ) {
        self.displayName = displayName
        self.storageNamespace = storageNamespace
        self.tagline = tagline
        self.baseSpeed = baseSpeed
        self.maxSpeed = maxSpeed
        self.speedRamp = speedRamp
        self.scoreRate = scoreRate
        self.background = background
        self.accent = accent
        self.obstacle = obstacle
        self.coin = coin
        self.skins = skins
        self.removeAdsProductID = removeAdsProductID
        self.coinPackProductIDs = coinPackProductIDs
        self.interstitialEveryDeaths = interstitialEveryDeaths
        self.rewardedAdUnitID = rewardedAdUnitID
        self.interstitialAdUnitID = interstitialAdUnitID
        self.leaderboardID = leaderboardID
    }

    public func skin(for id: String) -> Skin? { skins.first { $0.id == id } }
}
