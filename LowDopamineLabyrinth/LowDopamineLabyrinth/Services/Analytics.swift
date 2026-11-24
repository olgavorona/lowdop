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
        "fall_adventures",
        "thanksgiving_adventures"
    ]

    static func lockedLevel(in packID: String) -> PaywallSource {
        seasonalPackIDs.contains(packID) ? .seasonal : .freeLevels
    }

    static func lockedPack(_ packID: String) -> PaywallSource {
        seasonalPackIDs.contains(packID) ? .seasonal : .shelf
    }
}

enum Analytics {
    private static let disabledForTests = ProcessInfo.processInfo.arguments.contains("-uiTestDisableAnalytics")
        || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

#if DEBUG
    private static let capturesOnboarding = ProcessInfo.processInfo.arguments.contains("-uiTestRecordOnboardingAnalytics")
    private static let captureLock = NSLock()
    private static var captureURL: URL {
        let requestedName = ProcessInfo.processInfo.environment["ONBOARDING_ANALYTICS_CAPTURE"] ?? "session"
        let name = ["button", "swipe", "variant-a", "variant-b", "paywall-regular", "paywall-discount"].contains(requestedName) ? requestedName : "session"
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("onboarding-analytics-\(name).jsonl")
    }
#endif

    static var currentLocale: String {
        UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    }

    static func configure() {
#if DEBUG
        if capturesOnboarding {
            try? Data().write(to: captureURL)
            return
        }
#endif
        guard !disabledForTests else { return }
        let config = TelemetryDeck.Config(appID: "738FCE64-D2AE-483A-B5FB-CCCB26BD5E01")
        TelemetryDeck.initialize(config: config)
        CrashDiagnosticsReporter.shared.start()
    }

    static func send(_ event: String, with params: [String: String] = [:], floatValue: Double? = nil) {
        let parameters = OnboardingExperiment.analyticsParameters().merging(params) { _, value in value }
#if DEBUG
        if capturesOnboarding {
            captureLock.lock()
            defer { captureLock.unlock() }
            if let data = try? JSONSerialization.data(withJSONObject: ["event": event, "parameters": parameters]),
               let file = try? FileHandle(forWritingTo: captureURL) {
                defer { try? file.close() }
                _ = try? file.seekToEnd()
                try? file.write(contentsOf: data + Data([0x0A]))
            }
            return
        }
#endif
        guard !disabledForTests else { return }
        TelemetryDeck.signal(event, parameters: parameters, floatValue: floatValue)
    }

    static func error(_ id: String, message: String? = nil, parameters: [String: String] = [:]) {
#if DEBUG
        if capturesOnboarding { return }
#endif
        guard !disabledForTests else { return }
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

/// Tracks actual onboarding navigation, rather than SwiftUI's prefetched page appearances.
final class OnboardingAnalyticsTracker {
    enum Screen: Int, CaseIterable {
        case language, tutorial, labyrinths, calm, difficulty, paywall

        var name: String {
            switch self {
            case .language: "language"
            case .tutorial: "tutorial"
            case .labyrinths: "labyrinths"
            case .calm: "calm"
            case .difficulty: "difficulty"
            case .paywall: "paywall"
            }
        }

        var event: String {
            switch self {
            case .language: "Onboarding.languageShown"
            case .tutorial: "Onboarding.tutorialShown"
            case .labyrinths: "Onboarding.labyrinthsShown"
            case .calm: "Onboarding.calmShown"
            case .difficulty: "Onboarding.difficultyShown"
            case .paywall: "Onboarding.paywallShown"
            }
        }
    }

    enum Method: String {
        case button, swipe
        case tutorialCompleted = "tutorial_completed"
        case tutorialSkipped = "tutorial_skipped"
        case difficultyCard = "difficulty_card"
    }

    private let send: (String, [String: String]) -> Void
    private let variant: OnboardingExperimentVariant?
    private var experimentExposureRecorded = false
    private var visibleScreen: Screen?
    private var confirmedLanguage: AppLanguage?
    private var confirmedDifficulty: DifficultyLevel?
    private var languageWasChanged = false
    private var difficultyWasChanged = false
    private var tutorialOutcomeRecorded = false
    private var completionRecorded = false
    private var parentalGateVisible = false
    private var languagePickerSkipRecorded = false

    init(variant: OnboardingExperimentVariant? = nil,
         send: @escaping (String, [String: String]) -> Void = { Analytics.send($0, with: $1) }) {
        self.variant = variant
        self.send = send
    }

    func experimentExposed(page: Int, language: AppLanguage, difficulty: DifficultyLevel) {
        guard variant != nil, !experimentExposureRecorded, let screen = Screen(rawValue: page) else { return }
        experimentExposureRecorded = true
        emit("Onboarding.experimentExposed", screen: screen, language: language, difficulty: difficulty)
    }

    @discardableResult
    func screenShown(page: Int, language: AppLanguage, difficulty: DifficultyLevel) -> Bool {
        guard let screen = Screen(rawValue: page), screen != visibleScreen else { return false }
        visibleScreen = screen
        if screen == .language {
            confirmedLanguage = nil
            languageWasChanged = false
        }
        if screen == .difficulty {
            confirmedDifficulty = nil
            difficultyWasChanged = false
        }
        if screen == .tutorial { tutorialOutcomeRecorded = false }
        emit(screen.event, screen: screen, language: language, difficulty: difficulty)
        return true
    }

    func languageChanged(to language: AppLanguage, difficulty: DifficultyLevel) {
        languageWasChanged = true
        emit("Language.changed", screen: .language, language: language, difficulty: difficulty,
             extra: ["method": "menu"])
    }

    func languagePickerSkipped(language: AppLanguage, difficulty: DifficultyLevel) {
        guard !languagePickerSkipRecorded else { return }
        languagePickerSkipRecorded = true
        confirmedLanguage = language
        emit("Onboarding.languageSkipped", screen: .language, language: language, difficulty: difficulty,
             extra: ["method": "device_language", "reason": "device_english"])
        emit("Language.selected", screen: .language, language: language, difficulty: difficulty,
             extra: ["method": "device_language", "selection": "automatic"])
    }

    func difficultyChanged(to difficulty: DifficultyLevel, language: AppLanguage) {
        difficultyWasChanged = true
        emit("Onboarding.difficultyChanged", screen: .difficulty, language: language, difficulty: difficulty,
             extra: ["level": difficulty.rawValue, "method": Method.difficultyCard.rawValue])
    }

    /// A difficulty choice is accepted before opening the parental gate, as with a card tap.
    /// Retrying the same choice after canceling the gate must not count it twice.
    func forwardAttempt(from page: Int, to destination: Int, method: Method,
                        language: AppLanguage, difficulty: DifficultyLevel) {
        guard destination > page, Screen(rawValue: destination) != nil else { return }
        if page == Screen.language.rawValue, confirmedLanguage != language {
            confirmedLanguage = language
            emit("Language.selected", screen: .language, language: language, difficulty: difficulty,
                 extra: ["method": method.rawValue, "selection": languageWasChanged ? "explicit" : "unchanged"])
        }
        if page == Screen.difficulty.rawValue, confirmedDifficulty != difficulty {
            confirmedDifficulty = difficulty
            emit("Onboarding.difficultySelected", screen: .difficulty, language: language, difficulty: difficulty,
                 extra: ["level": difficulty.rawValue, "method": method.rawValue,
                         "selection": difficultyWasChanged ? "explicit" : "unchanged"])
        }
    }

    func transitioned(from page: Int, to destination: Int, method: Method,
                      language: AppLanguage, difficulty: DifficultyLevel) {
        guard destination > page, let screen = Screen(rawValue: page),
              let target = Screen(rawValue: destination) else { return }
        forwardAttempt(from: page, to: destination, method: method, language: language, difficulty: difficulty)
        if screen == .tutorial {
            tutorialOutcome(completed: method == .tutorialCompleted, method: method,
                            language: language, difficulty: difficulty)
        }
        emit("Onboarding.screenContinued", screen: screen, language: language, difficulty: difficulty,
             extra: ["to_screen": target.name, "method": method.rawValue])
    }

    func tutorialOutcome(completed: Bool, method: Method, language: AppLanguage, difficulty: DifficultyLevel) {
        guard !tutorialOutcomeRecorded else { return }
        tutorialOutcomeRecorded = true
        emit(completed ? "Onboarding.tutorialCompleted" : "Onboarding.tutorialSkipped",
             screen: .tutorial, language: language, difficulty: difficulty, extra: ["method": method.rawValue])
    }

    func tutorialAudioStarted(_ started: Bool, language: AppLanguage, difficulty: DifficultyLevel) {
        emit("Onboarding.tutorialAudioStarted", screen: .tutorial, language: language, difficulty: difficulty,
             extra: ["started": String(started)])
    }

    func parentalGateShown(method: Method, language: AppLanguage, difficulty: DifficultyLevel) {
        guard !parentalGateVisible else { return }
        parentalGateVisible = true
        emit("Onboarding.parentalGateShown", screen: .difficulty, language: language, difficulty: difficulty,
             extra: ["screen": "parental_gate", "method": method.rawValue])
    }

    func parentalGateFinished(passed: Bool, method: Method, language: AppLanguage, difficulty: DifficultyLevel) {
        guard parentalGateVisible else { return }
        parentalGateVisible = false
        emit(passed ? "Onboarding.parentalGatePassed" : "Onboarding.parentalGateCancelled",
             screen: .difficulty, language: language, difficulty: difficulty,
             extra: ["screen": "parental_gate", "method": method.rawValue])
    }

    func completed(language: AppLanguage, difficulty: DifficultyLevel) {
        guard !completionRecorded else { return }
        completionRecorded = true
        emit("Onboarding.completed", screen: .paywall, language: language, difficulty: difficulty)
    }

    private func emit(_ event: String, screen: Screen, language: AppLanguage,
                      difficulty: DifficultyLevel, extra: [String: String] = [:]) {
        let context = ["source": "onboarding", "screen": screen.name, "step": String(screen.rawValue + 1),
                       "app_locale": language.rawValue, "language": language.rawValue,
                       "difficulty": difficulty.rawValue, "onboarding_analytics_version": "2"]
        let experimentContext = context.merging(variant?.analyticsParameters ?? [:]) { _, value in value }
        send(event, experimentContext.merging(extra) { _, value in value })
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
