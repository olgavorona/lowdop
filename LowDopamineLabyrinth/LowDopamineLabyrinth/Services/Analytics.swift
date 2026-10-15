import StoreKit
import TelemetryDeck
import UIKit
import MetricKit

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
    static var currentLocale: String {
        UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    }

    static func configure() {
        let config = TelemetryDeck.Config(appID: "738FCE64-D2AE-483A-B5FB-CCCB26BD5E01")
        TelemetryDeck.initialize(config: config)
        CrashDiagnosticsReporter.shared.start()
    }

    static func send(_ event: String, with params: [String: String] = [:]) {
        TelemetryDeck.signal(event, parameters: params)
    }

    static func error(_ id: String, message: String? = nil, parameters: [String: String] = [:]) {
        var context = parameters
        context["app_locale"] = context["app_locale"] ?? currentLocale
        TelemetryDeck.errorOccurred(
            id: id,
            category: .thrownException,
            message: message,
            parameters: context
        )
    }
}

private final class CrashDiagnosticsReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashDiagnosticsReporter()
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashCount = payload.crashDiagnostics?.count ?? 0
            guard crashCount > 0 else { continue }
            Analytics.error(
                "App.crashDiagnostic",
                message: "MetricKit delivered crash diagnostics.",
                parameters: [
                    "diagnostic_count": String(crashCount),
                    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                    "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
                ]
            )
        }
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
