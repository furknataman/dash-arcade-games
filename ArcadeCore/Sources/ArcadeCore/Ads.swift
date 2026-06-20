import Foundation

/// Abstraction over a rewarded/interstitial ad network. The core never depends
/// on a concrete SDK — the app injects an implementation (AdMob, AppLovin, …).
/// `StubAdsProvider` is used in the simulator/dev and for "Remove Ads" users.
@MainActor
public protocol AdsProviding: AnyObject {
    /// True when a rewarded ad is loaded and ready to present.
    var isRewardedReady: Bool { get }
    /// Kick off loading of the next rewarded + interstitial ads.
    func preload()
    /// Present a rewarded ad. `completion(true)` only if the reward was earned.
    func showRewarded(_ completion: @escaping (Bool) -> Void)
    /// Present an interstitial. `completion()` fires when it is dismissed.
    func showInterstitial(_ completion: @escaping () -> Void)
}

/// No-network provider. Grants rewards immediately — perfect for development,
/// the simulator, and "Remove Ads" players (who should never see real ads).
@MainActor
public final class StubAdsProvider: AdsProviding {
    private let grantRewards: Bool
    public init(grantRewards: Bool = true) { self.grantRewards = grantRewards }

    public var isRewardedReady: Bool { true }
    public func preload() {}
    public func showRewarded(_ completion: @escaping (Bool) -> Void) { completion(grantRewards) }
    public func showInterstitial(_ completion: @escaping () -> Void) { completion() }
}
