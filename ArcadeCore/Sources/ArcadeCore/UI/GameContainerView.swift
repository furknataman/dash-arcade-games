import SwiftUI
import SpriteKit

/// Root view for any ArcadeCore game: the SpriteKit scene with phase-driven
/// SwiftUI overlays (menu / HUD / pause / game-over) and a shop sheet. The game
/// builds the scene + objects and hands them in.
public struct GameContainerView: View {
    @ObservedObject private var model: GameModel
    @ObservedObject private var storage: GameStorage
    @ObservedObject private var store: StoreManager
    private let config: GameConfig
    private let scene: SKScene

    public init(model: GameModel, storage: GameStorage, store: StoreManager,
                config: GameConfig, scene: SKScene) {
        self.model = model
        self.storage = storage
        self.store = store
        self.config = config
        self.scene = scene
    }

    public var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            switch model.phase {
            case .ready:
                MainMenuView(model: model, storage: storage, config: config)
                    .transition(.opacity)
            case .playing:
                HUDView(model: model, config: config)
            case .paused:
                PauseView(model: model, config: config)
                    .transition(.opacity)
            case .dead:
                GameOverView(model: model, config: config)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.phase)
        .sheet(isPresented: $model.showShop) {
            ShopView(model: model, storage: storage, store: store, config: config)
        }
        .task { await store.load() }
        .onAppear { syncSettings() }
        .onChange(of: storage.soundEnabled) { _, on in AudioManager.shared.enabled = on }
        .onChange(of: storage.hapticsEnabled) { _, on in Haptics.enabled = on }
    }

    private func syncSettings() {
        AudioManager.shared.enabled = storage.soundEnabled
        Haptics.enabled = storage.hapticsEnabled
    }
}
