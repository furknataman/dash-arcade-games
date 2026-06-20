import UIKit
import GoogleMobileAds
import AppTrackingTransparency
import ArcadeCore

/// AdMob-backed `AdsProviding`. Loads/presents rewarded and interstitial ads
/// and recycles each ad after it is dismissed. Reusable across every game — a
/// game just passes its ad-unit ids.
@MainActor
public final class AdMobAdsProvider: NSObject, AdsProviding, GADFullScreenContentDelegate {

    private let rewardedUnitID: String
    private let interstitialUnitID: String

    private var rewarded: GADRewardedAd?
    private var interstitial: GADInterstitialAd?

    private var rewardedEarned = false
    private var rewardedCompletion: ((Bool) -> Void)?
    private var interstitialCompletion: (() -> Void)?

    public init(rewardedUnitID: String, interstitialUnitID: String) {
        self.rewardedUnitID = rewardedUnitID
        self.interstitialUnitID = interstitialUnitID
        super.init()
    }

    /// Initialize the SDK once at launch. Safe to call before ATT resolves.
    public static func start() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    /// Start the SDK and preload ads ONLY after init completes. Loading before
    /// the SDK is ready can fail silently — this is the reliable path.
    public func startAndPreload() {
        GADMobileAds.sharedInstance().start { [weak self] _ in
            self?.preload()
        }
    }

    /// Register devices that should receive TEST ads even with real ad-unit ids.
    /// Simulators are test devices automatically; add a physical device's hash
    /// (printed in the Xcode console on first ad request) to test safely on it.
    /// Tapping REAL ads on a non-test device can get your AdMob account banned.
    public static func setTestDevices(_ identifiers: [String]) {
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = identifiers
    }

    /// Ask for tracking permission, then (re)start the SDK. iOS shows the ATT
    /// prompt only once; declining still allows non-personalized ads.
    public static func requestTrackingThenStart() {
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { start() }
        }
    }

    public var isRewardedReady: Bool { rewarded != nil }

    public func preload() {
        loadRewarded()
        loadInterstitial()
    }

    private func loadRewarded() {
        GADRewardedAd.load(withAdUnitID: rewardedUnitID, request: GADRequest()) { [weak self] ad, _ in
            guard let self else { return }
            self.rewarded = ad
            ad?.fullScreenContentDelegate = self
        }
    }

    private func loadInterstitial() {
        GADInterstitialAd.load(withAdUnitID: interstitialUnitID, request: GADRequest()) { [weak self] ad, _ in
            guard let self else { return }
            self.interstitial = ad
            ad?.fullScreenContentDelegate = self
        }
    }

    public func showRewarded(_ completion: @escaping (Bool) -> Void) {
        guard let rewarded, let root = Self.topViewController() else {
            completion(false)
            loadRewarded()
            return
        }
        rewardedEarned = false
        rewardedCompletion = completion
        rewarded.present(fromRootViewController: root) { [weak self] in
            self?.rewardedEarned = true
        }
    }

    public func showInterstitial(_ completion: @escaping () -> Void) {
        guard let interstitial, let root = Self.topViewController() else {
            completion()
            loadInterstitial()
            return
        }
        interstitialCompletion = completion
        interstitial.present(fromRootViewController: root)
    }

    // MARK: GADFullScreenContentDelegate
    public func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        finish(success: rewardedEarned)
    }

    public func ad(_ ad: GADFullScreenPresentingAd,
                   didFailToPresentFullScreenContentWithError error: Error) {
        finish(success: false)
    }

    /// Fire whichever completion is pending and queue up the next ad.
    private func finish(success: Bool) {
        if let rc = rewardedCompletion {
            rewardedCompletion = nil
            rewarded = nil
            rc(success)
            loadRewarded()
        }
        if let ic = interstitialCompletion {
            interstitialCompletion = nil
            interstitial = nil
            ic()
            loadInterstitial()
        }
    }

    // MARK: Helpers
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        let keyWindow = windows.first { $0.isKeyWindow } ?? windows.first
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
