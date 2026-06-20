import Foundation
import Combine

/// Persistent player state shared by every game built on ArcadeCore.
/// Backed by `UserDefaults`; keys are namespaced so multiple games can share
/// one device build without colliding (pass a unique `namespace`).
public final class GameStorage: ObservableObject {

    private let defaults: UserDefaults
    private let ns: String

    @Published public private(set) var bestScore: Int
    @Published public private(set) var coins: Int
    @Published public private(set) var removeAdsPurchased: Bool
    @Published public private(set) var selectedSkinID: String
    @Published public private(set) var unlockedSkinIDs: Set<String>
    @Published public var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: key("sound")) } }
    @Published public var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: key("haptics")) } }

    public init(namespace: String, defaults: UserDefaults = .standard, defaultSkinID: String = "default") {
        self.defaults = defaults
        self.ns = namespace
        self.bestScore = defaults.integer(forKey: "\(namespace).best")
        self.coins = defaults.integer(forKey: "\(namespace).coins")
        self.removeAdsPurchased = defaults.bool(forKey: "\(namespace).removeAds")
        self.selectedSkinID = defaults.string(forKey: "\(namespace).skin") ?? defaultSkinID
        let unlocked = defaults.stringArray(forKey: "\(namespace).unlocked") ?? [defaultSkinID]
        self.unlockedSkinIDs = Set(unlocked)
        self.soundEnabled = defaults.object(forKey: "\(namespace).sound") as? Bool ?? true
        self.hapticsEnabled = defaults.object(forKey: "\(namespace).haptics") as? Bool ?? true
    }

    private func key(_ k: String) -> String { "\(ns).\(k)" }

    // MARK: Score
    @discardableResult
    public func submit(score: Int) -> Bool {
        guard score > bestScore else { return false }
        bestScore = score
        defaults.set(score, forKey: key("best"))
        return true
    }

    // MARK: Coins
    public func addCoins(_ amount: Int) {
        coins = max(0, coins + amount)
        defaults.set(coins, forKey: key("coins"))
    }

    @discardableResult
    public func spendCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        defaults.set(coins, forKey: key("coins"))
        return true
    }

    // MARK: Skins
    public func isUnlocked(_ id: String) -> Bool { unlockedSkinIDs.contains(id) }

    public func unlock(_ id: String) {
        unlockedSkinIDs.insert(id)
        defaults.set(Array(unlockedSkinIDs), forKey: key("unlocked"))
    }

    public func select(_ id: String) {
        guard unlockedSkinIDs.contains(id) else { return }
        selectedSkinID = id
        defaults.set(id, forKey: key("skin"))
    }

    // MARK: IAP
    public func setRemoveAdsPurchased(_ value: Bool) {
        removeAdsPurchased = value
        defaults.set(value, forKey: key("removeAds"))
    }
}
