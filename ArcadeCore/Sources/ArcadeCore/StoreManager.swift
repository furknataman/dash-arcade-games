import StoreKit

/// StoreKit 2 wrapper: loads products, runs purchases, restores, and keeps a
/// live set of owned product ids. Drives "Remove Ads" and coin-pack IAPs.
@MainActor
public final class StoreManager: ObservableObject {
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var isLoading = false

    private let productIDs: [String]
    private var updatesTask: Task<Void, Never>?

    /// Called (on the main actor) with a product id whenever a purchase or
    /// restore is verified. The app maps this to entitlements (e.g. remove ads,
    /// grant coins).
    public var onEntitlement: ((String) -> Void)?

    public init(productIDs: [String]) {
        self.productIDs = productIDs
        updatesTask = listenForTransactions()
    }

    deinit { updatesTask?.cancel() }

    public func load() async {
        guard !productIDs.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: productIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
        await refreshEntitlements()
    }

    public func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    /// Returns true if the purchase completed and was verified.
    @discardableResult
    public func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = try? checkVerified(verification) {
                    purchasedProductIDs.insert(transaction.productID)
                    onEntitlement?(transaction.productID)
                    await transaction.finish()
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    public func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    public func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            purchasedProductIDs.insert(transaction.productID)
            onEntitlement?(transaction.productID)
        }
    }

    // MARK: Private
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? self.checkVerified(update) {
                    await MainActor.run {
                        self.purchasedProductIDs.insert(transaction.productID)
                        self.onEntitlement?(transaction.productID)
                    }
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }
}
