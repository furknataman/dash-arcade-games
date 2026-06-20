import SwiftUI
import StoreKit

/// Reusable shop: cosmetic skins (bought with coins), a "Remove Ads" IAP and
/// Restore Purchases. Entitlement mapping (productID → storage) is wired by the
/// game via `StoreManager.onEntitlement`.
public struct ShopView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var storage: GameStorage
    @ObservedObject var store: StoreManager
    let config: GameConfig
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    coinsHeader
                    skinsSection
                    iapSection
                }
                .padding()
            }
            .background(Color(config.background).ignoresSafeArea())
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
        .tint(Color(config.accent))
    }

    private var coinsHeader: some View {
        HStack {
            Text("🪙 \(storage.coins)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Color(config.coin))
            Spacer()
        }
    }

    private var skinsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SKINS").font(.headline).foregroundStyle(.white.opacity(0.7))
            ForEach(config.skins) { skin in
                skinRow(skin)
            }
        }
    }

    private func skinRow(_ skin: Skin) -> some View {
        let unlocked = storage.isUnlocked(skin.id)
        let selected = storage.selectedSkinID == skin.id
        return HStack(spacing: 14) {
            Circle().fill(Color(skin.color)).frame(width: 36, height: 36)
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
            Text(skin.name).font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if selected {
                Text("SELECTED").font(.caption.bold()).foregroundStyle(Color(config.accent))
            } else if unlocked {
                Button("Select") { storage.select(skin.id) }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            } else {
                Button {
                    if storage.spendCoins(skin.price) {
                        storage.unlock(skin.id)
                        storage.select(skin.id)
                        Haptics.notify(.success)
                    } else {
                        Haptics.notify(.error)
                    }
                } label: {
                    Text("🪙 \(skin.price)").font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .disabled(storage.coins < skin.price)
                .opacity(storage.coins < skin.price ? 0.4 : 1)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
    }

    private var iapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STORE").font(.headline).foregroundStyle(.white.opacity(0.7))

            if storage.removeAdsPurchased {
                Label("Ads removed — thank you!", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(config.accent))
                    .padding(.vertical, 8)
            } else {
                Button {
                    Task { await buyRemoveAds() }
                } label: {
                    HStack {
                        Text("Remove Ads")
                        Spacer()
                        Text(removeAdsPrice)
                    }
                }
                .buttonStyle(ArcadeButtonStyle(fill: Color(config.accent),
                                               foreground: Color(config.background)))
                .disabled(working)
            }

            Button("Restore Purchases") {
                Task { working = true; await store.restore(); working = false }
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private var removeAdsPrice: String {
        store.product(for: config.removeAdsProductID)?.displayPrice ?? "—"
    }

    private func buyRemoveAds() async {
        guard let product = store.product(for: config.removeAdsProductID) else { return }
        working = true
        _ = await store.purchase(product)
        working = false
    }
}
