import StoreKit
import TelemetryDeck
import UIKit

enum PaywallSource: String {
    case onboarding
    case freeLevels = "free_levels"
    case seasonal
    case shelf
    case settings

    private static let seasonalPackIDs: Set<String> = [
        "fall_adventures"
    ]

    static func lockedLevel(in packID: String) -> PaywallSource {
        seasonalPackIDs.contains(packID) ? .seasonal : .freeLevels
    }

    static func lockedPack(_ packID: String) -> PaywallSource {
        seasonalPackIDs.contains(packID) ? .seasonal : .shelf
    }
}

enum Analytics {
    static func configure() {
        let config = TelemetryDeck.Config(appID: "738FCE64-D2AE-483A-B5FB-CCCB26BD5E01")
        TelemetryDeck.initialize(config: config)
    }

    static func send(_ event: String, with params: [String: String] = [:]) {
        TelemetryDeck.signal(event, parameters: params)
    }
}

enum ReviewRequestTrigger: String {
    case firstAccountOpen
    case accountButton
    case onboardingPurchase
    case purchase
}

@MainActor
final class ReviewRequestManager: ObservableObject {
    private let defaults = UserDefaults.standard

    private let firstAccountOpenKey = "hasRequestedReviewAfterFirstAccountOpen"
    private let onboardingPurchaseKey = "hasRequestedReviewAfterOnboardingPurchase"
    private let purchaseKey = "hasRequestedReviewAfterPurchase"

    func requestAfterFirstAccountOpen() {
        requestOnce(key: firstAccountOpenKey, trigger: .firstAccountOpen)
    }

    func requestFromAccountButton() {
        request(trigger: .accountButton)
    }

    func requestAfterSuccessfulOnboardingPurchase(isPremium: Bool) {
        guard isPremium else { return }
        requestOnce(key: onboardingPurchaseKey, trigger: .onboardingPurchase)
    }

    func requestAfterSuccessfulPurchase(isPremium: Bool) {
        guard isPremium else { return }
        requestOnce(key: purchaseKey, trigger: .purchase)
    }

    private func requestOnce(key: String, trigger: ReviewRequestTrigger) {
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        request(trigger: trigger)
    }

    private func request(trigger: ReviewRequestTrigger) {
        Analytics.send("Review.requested", with: ["trigger": trigger.rawValue])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else {
                Analytics.send("Review.requestSkipped", with: [
                    "trigger": trigger.rawValue,
                    "reason": "no_active_scene"
                ])
                return
            }

            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
