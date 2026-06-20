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
    let scene: JumpScene

    init() {
        let cfg = GameConfig(
            displayName: "Jump Dash",
            storageNamespace: "jumpdash",
            tagline: "TAP TO JUMP",
            baseSpeed: 300, maxSpeed: 520, speedRamp: 6, scoreRate: 0.1,
            background: RGBA(hex: 0x1B1330),
            accent: RGBA(hex: 0x67E8F9),
            obstacle: RGBA(hex: 0xFF5C8A),
            coin: RGBA(hex: 0xFFD23F),
            skins: [
                Skin(id: "default", name: "Frost",  color: RGBA(hex: 0x9BE8FF), price: 0),
                Skin(id: "magma",   name: "Magma",  color: RGBA(hex: 0xFF7A59), price: 150),
                Skin(id: "mint",    name: "Mint",   color: RGBA(hex: 0x6CE0A8), price: 300),
                Skin(id: "grape",   name: "Grape",  color: RGBA(hex: 0xC58BFF), price: 500),
                Skin(id: "gold",    name: "Gold",   color: RGBA(hex: 0xFFD23F), price: 1000),
            ],
            removeAdsProductID: "com.solvy.jumpdash.removeads",
            interstitialEveryDeaths: 3,
            leaderboardID: "jumpdash.high_score"
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

        self.scene = JumpScene(size: CGSize(width: 390, height: 844),
                               config: cfg, model: model, storage: storage, ads: adsProvider)

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
                          scene: host.scene)
    }
}
