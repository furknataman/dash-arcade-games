import SwiftUI
import ArcadeCore
import ArcadeCoreAdMob

/// Owns the game's config and long-lived objects, wired once. To make a new
/// game on ArcadeCore you mostly copy this file, swap the `GameConfig` and the
/// scene subclass.
@MainActor
final class GameHost: ObservableObject {
    let config: GameConfig
    let model = GameModel()
    let storage: GameStorage
    let store: StoreManager
    let ads: AdsProviding
    let scene: GravityFlipScene
    /// Home-screen banner (nil in automated runs / when ads are removed).
    let menuBanner: AnyView?

    init() {
        let cfg = GameConfig(
            displayName: "Gravity Dash",
            storageNamespace: "gravitydash",
            tagline: "TAP TO FLIP GRAVITY",
            baseSpeed: 320, maxSpeed: 640, speedRamp: 7, scoreRate: 0.1,
            background: RGBA(hex: 0x0D0F1E),
            accent: RGBA(hex: 0x40E5D9),
            obstacle: RGBA(hex: 0xFF5C6B),
            coin: RGBA(hex: 0xFFD13F),
            skins: [
                Skin(id: "default", name: "Aqua",   color: RGBA(hex: 0x40E5D9), price: 0),
                Skin(id: "sunset",  name: "Sunset", color: RGBA(hex: 0xFF8A5B), price: 150),
                Skin(id: "grape",   name: "Grape",  color: RGBA(hex: 0xB06CF0), price: 300),
                Skin(id: "lime",    name: "Lime",   color: RGBA(hex: 0xA8E05F), price: 500),
                Skin(id: "gold",    name: "Gold",   color: RGBA(hex: 0xFFD13F), price: 1000),
            ],
            removeAdsProductID: "com.solvy.gravitydash.removeads",
            interstitialEveryDeaths: 3,
            rewardedAdUnitID: "ca-app-pub-1226731828520786/6179050056",
            interstitialAdUnitID: "ca-app-pub-1226731828520786/2259986342",
            bannerAdUnitID: "ca-app-pub-1226731828520786/5972723422",
            leaderboardID: "gravitydash.high_score"
        )
        self.config = cfg

        let storage = GameStorage(namespace: cfg.storageNamespace)
        self.storage = storage

        let store = StoreManager(productIDs: [cfg.removeAdsProductID])
        self.store = store

        // Stub (instant rewards, no network) for automated runs; real AdMob
        // otherwise. Test ad-unit ids ship by default — swap for real ones +
        // the GADApplicationIdentifier in Info.plist before release.
        let useStub = CommandLine.arguments.contains("-autoplay")
            || CommandLine.arguments.contains("-demo")
            || CommandLine.arguments.contains("-stubads")
        let adsProvider: AdsProviding
        if useStub {
            adsProvider = StubAdsProvider()
        } else {
            // BAN SAFETY: DEBUG builds always use Google TEST ad units, so we
            // never request real ads while developing. Release uses the real
            // ids; simulators auto-serve test ads, and you can add a physical
            // device hash below to test the real-id build safely.
            let testDeviceIDs: [String] = []  // e.g. ["2077ef9a63d2b398840261c8221a0c9b"]
            // Real ads ONLY in the public App Store build. DEBUG *and* TestFlight
            // (sandbox receipt) serve Google TEST ads, so you can tap your own
            // ads while testing without risking an AdMob ban.
            let isSandbox = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
            #if DEBUG
            let useTestAds = true
            #else
            let useTestAds = isSandbox
            #endif
            let rewardedID = useTestAds ? "ca-app-pub-3940256099942544/1712485313" : cfg.rewardedAdUnitID
            let interstitialID = useTestAds ? "ca-app-pub-3940256099942544/4411468910" : cfg.interstitialAdUnitID
            AdMobAdsProvider.setTestDevices(testDeviceIDs)
            let admob = AdMobAdsProvider(rewardedUnitID: rewardedID, interstitialUnitID: interstitialID)
            admob.startAndPreload()  // start SDK, then load ads in the completion
            adsProvider = admob
        }
        self.ads = adsProvider

        // Game Center: authenticate + enable the leaderboard (skip in automated runs).
        if !useStub {
            GameCenter.shared.start(leaderboardID: cfg.leaderboardID)
        }

        self.scene = GravityFlipScene(size: CGSize(width: 390, height: 844),
                                      config: cfg, model: model, storage: storage, ads: adsProvider)

        // Home-screen banner: real id only in the public App Store build;
        // DEBUG + TestFlight use Google's TEST banner (ban-safe). None in
        // automated runs.
        if useStub {
            self.menuBanner = nil
        } else if let bannerID = cfg.bannerAdUnitID {
            let isSandbox = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
            #if DEBUG
            let id = "ca-app-pub-3940256099942544/2934735716"        // Google TEST banner
            #else
            let id = isSandbox ? "ca-app-pub-3940256099942544/2934735716" : bannerID
            #endif
            self.menuBanner = AnyView(BannerAdView(adUnitID: id))
        } else {
            self.menuBanner = nil
        }

        // Map verified purchases to entitlements.
        store.onEntitlement = { [storage] productID in
            if productID == cfg.removeAdsProductID {
                storage.setRemoveAdsPurchased(true)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var host = GameHost()

    var body: some View {
        GameContainerView(model: host.model,
                          storage: host.storage,
                          store: host.store,
                          config: host.config,
                          scene: host.scene,
                          menuBanner: host.menuBanner)
    }
}
