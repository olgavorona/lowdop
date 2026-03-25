import StoreKit

class SubscriptionManager: ObservableObject {
    @Published var isPremium: Bool = false
    @Published var products: [Product] = []

    private let productIds = [
        "labyrinth_unlimited_weekly",
        "labyrinth_unlimited_monthly",
        "labyrinth_unlimited_lifetime1"
    ]
    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        Task { await checkEntitlements() }
    }

    deinit {
        transactionListener?.cancel()
    }

    @MainActor
    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: productIds)
            // Sort in preferred display order: weekly, monthly, lifetime
            products = productIds.compactMap { id in loaded.first { $0.id == id } }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    @MainActor
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPremium = true
                return true
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("Purchase failed: \(error)")
            return false
        }
    }

    @MainActor
    func restorePurchases() async {
        try? await AppStore.sync()
        await checkEntitlements()
    }

    @MainActor
    private func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if productIds.contains(transaction.productID) {
                    isPremium = true
                    return
                }
            }
        }
        isPremium = false
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await transaction.finish()
                    await self?.checkEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let item):
            return item
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
