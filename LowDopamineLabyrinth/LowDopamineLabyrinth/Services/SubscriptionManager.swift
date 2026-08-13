import StoreKit

enum PaywallStrategy {
    case anchorThenDiscount
    case directLifetime
}

class SubscriptionManager: ObservableObject {
    @Published var isPremium: Bool = false
    @Published var products: [Product] = []
    @Published var hasSeenInitialPaywall: Bool {
        didSet { defaults.set(hasSeenInitialPaywall, forKey: hasSeenInitialPaywallKey) }
    }
    @Published var hasCompletedFreeExperience: Bool {
        didSet { defaults.set(hasCompletedFreeExperience, forKey: hasCompletedFreeExperienceKey) }
    }
    @Published var numberOfFreeMazesCompleted: Int {
        didSet { defaults.set(numberOfFreeMazesCompleted, forKey: numberOfFreeMazesCompletedKey) }
    }
    @Published var isDiscountEligible: Bool {
        didSet { defaults.set(isDiscountEligible, forKey: isDiscountEligibleKey) }
    }

    let paywallStrategy: PaywallStrategy = .anchorThenDiscount
    let regularFullAccessProductId = "labyrinth_unlimited_lifetime1"
    let discountFullAccessProductId = "labyrinth_unlimited_lifetime_discount"

    var fullAccessProductId: String {
        switch paywallStrategy {
        case .anchorThenDiscount:
            return isDiscountEligible ? discountFullAccessProductId : regularFullAccessProductId
        case .directLifetime:
            return discountFullAccessProductId
        }
    }

    var regularFullAccessProduct: Product? { product(withId: regularFullAccessProductId) }
    var discountFullAccessProduct: Product? { product(withId: discountFullAccessProductId) }
    var fullAccessProduct: Product? { product(withId: fullAccessProductId) }

    private var transactionListener: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let hasSeenInitialPaywallKey = "hasSeenInitialPaywall"
    private let hasCompletedFreeExperienceKey = "hasCompletedFreeExperience"
    private let numberOfFreeMazesCompletedKey = "numberOfFreeMazesCompleted"
    private let isDiscountEligibleKey = "isDiscountEligible"

    init() {
        hasSeenInitialPaywall = defaults.bool(forKey: hasSeenInitialPaywallKey)
        hasCompletedFreeExperience = defaults.bool(forKey: hasCompletedFreeExperienceKey)
        numberOfFreeMazesCompleted = defaults.integer(forKey: numberOfFreeMazesCompletedKey)
        isDiscountEligible = defaults.bool(forKey: isDiscountEligibleKey)
        let isUITestCompletionFlow = ProcessInfo.processInfo.arguments.contains("-uiTestShowCompletionForLastLevel")
        if isUITestCompletionFlow {
            isPremium = true
        }
        transactionListener = listenForTransactions()
        if !isUITestCompletionFlow {
            Task { await checkEntitlements() }
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    @MainActor
    func loadProducts() async {
        do {
            products = try await Product.products(for: [
                regularFullAccessProductId,
                discountFullAccessProductId
            ])
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
        let hadPremium = isPremium
        Analytics.send("restore_started")
        try? await AppStore.sync()
        await checkEntitlements()
        Analytics.send(isPremium ? "restore_success" : "restore_failed", with: [
            "restored_access": String(isPremium),
            "had_access_before_restore": String(hadPremium)
        ])
    }

    @MainActor
    func checkEntitlements() async {
        var hasFullAccess = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if isFullAccessProduct(transaction.productID) {
                    hasFullAccess = true
                }
            }
        }
        isPremium = hasFullAccess
    }

    func markInitialPaywallSeen() {
        hasSeenInitialPaywall = true
    }

    func markFreeExperienceCompleted() {
        hasCompletedFreeExperience = true
    }

    func enableDiscountEligibility() {
        isDiscountEligible = true
    }

    @discardableResult
    func recordFreeMazeCompletedIfNeeded(mazeId: String) -> Int? {
        guard numberOfFreeMazesCompleted < 3 else { return nil }
        numberOfFreeMazesCompleted += 1
        if numberOfFreeMazesCompleted >= 3 {
            markFreeExperienceCompleted()
        }
        return numberOfFreeMazesCompleted
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

    private func product(withId id: String) -> Product? {
        products.first { $0.id == id }
    }

    private func isFullAccessProduct(_ productID: String) -> Bool {
        productID == regularFullAccessProductId || productID == discountFullAccessProductId
    }

    enum StoreError: Error {
        case failedVerification
    }
}
