import StoreKit
import UIKit // UIApplication.shared, UIWindowScene

class SubscriptionManager: ObservableObject {
    @Published var isPremium: Bool = false
    @Published var products: [Product] = []
    @Published var activeSubscriptionProductId: String? = nil

    private let subscriptionIds = [
        "labyrinth_unlimited_weekly",
        "labyrinth_unlimited_monthly"
    ]
    private let lifetimeId = "labyrinth_unlimited_lifetime1"
    private var productIds: [String] { subscriptionIds + [lifetimeId] }
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
                await checkEntitlements()
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
    func openSubscriptionManagement() async {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }

    @MainActor
    func checkEntitlements() async {
        var hasLifetime = false
        var activeSubId: String? = nil

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == lifetimeId {
                    hasLifetime = true
                } else if subscriptionIds.contains(transaction.productID) {
                    activeSubId = transaction.productID
                }
            }
        }
        isPremium = hasLifetime || activeSubId != nil
        activeSubscriptionProductId = activeSubId
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
