import SwiftUI
import ArcadeCore
import ArcadeCoreAdMob

@MainActor
final class GameHost: ObservableObject {
    let config: GameConfig
    let model = GameModel()
    let storage: GameStorage
    let store: StoreManager
    let ads: AdsProviding
    let scene: FlapScene
    let menuBanner: AnyView?

    init() {
        let cfg = GameConfig(
            displayName: "Flap Dash",
            storageNamespace: "flapdash",
            tagline: "TAP TO FLAP",
            baseSpeed: 200, maxSpeed: 340, speedRamp: 4, scoreRate: 0.1,
            background: RGBA(hex: 0x0C1733),
            accent: RGBA(hex: 0xFFD23F),
            obstacle: RGBA(hex: 0x49C628),
            coin: RGBA(hex: 0xFFE08A),
            skins: [
                Skin(id: "default", name: "Canary",   color: RGBA(hex: 0xFFD23F), price: 0),
                Skin(id: "robin",   name: "Robin",    color: RGBA(hex: 0xFF6B5C), price: 150),
                Skin(id: "bluebird", name: "Bluebird", color: RGBA(hex: 0x4FC3F7), price: 300),
                Skin(id: "parrot",  name: "Parrot",   color: RGBA(hex: 0x66E06A), price: 500),
                Skin(id: "dove",    name: "Dove",     color: RGBA(hex: 0xF0F0F0), price: 1000),
            ],
            removeAdsProductID: "com.solvy.flapdash.removeads",
            interstitialEveryDeaths: 3,
            // Google TEST banner placeholder — replace with FlapDash's real
            // banner unit id once created in AdMob.
            bannerAdUnitID: "ca-app-pub-3940256099942544/2934735716",
            leaderboardID: "flapdash.high_score"
        )
        self.config = cfg

        let storage = GameStorage(namespace: cfg.storageNamespace)
        self.storage = storage
        let store = StoreManager(productIDs: [cfg.removeAdsProductID])
        self.store = store

        let useStub = CommandLine.arguments.contains("-autoplay")
            || CommandLine.arguments.contains("-demo")
            || CommandLine.arguments.contains("-stubads")
        let adsProvider: AdsProviding
        if useStub {
            adsProvider = StubAdsProvider()
        } else {
            // Real ads only in the public App Store build; DEBUG + TestFlight
            // use Google TEST ad units (ban-safe). Add your real ids later.
            let isSandbox = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
            #if DEBUG
            let useTestAds = true
            #else
            let useTestAds = isSandbox
            #endif
            let rewardedID = useTestAds ? "ca-app-pub-3940256099942544/1712485313" : cfg.rewardedAdUnitID
            let interstitialID = useTestAds ? "ca-app-pub-3940256099942544/4411468910" : cfg.interstitialAdUnitID
            AdMobAdsProvider.setTestDevices([])
            let admob = AdMobAdsProvider(rewardedUnitID: rewardedID, interstitialUnitID: interstitialID)
            admob.startAndPreload()
            adsProvider = admob
        }
        self.ads = adsProvider

        if !useStub {
            GameCenter.shared.start(leaderboardID: cfg.leaderboardID)
        }

        self.scene = FlapScene(size: CGSize(width: 390, height: 844),
                               config: cfg, model: model, storage: storage, ads: adsProvider)

        if useStub {
            self.menuBanner = nil
        } else if let bannerID = cfg.bannerAdUnitID {
            let isSandbox = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
            #if DEBUG
            let id = "ca-app-pub-3940256099942544/2934735716"
            #else
            let id = isSandbox ? "ca-app-pub-3940256099942544/2934735716" : bannerID
            #endif
            self.menuBanner = AnyView(BannerAdView(adUnitID: id))
        } else {
            self.menuBanner = nil
        }

        store.onEntitlement = { [storage] productID in
            if productID == cfg.removeAdsProductID { storage.setRemoveAdsPurchased(true) }
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
