import Foundation

enum OnboardingExperimentVariant: String, CaseIterable {
    case a = "A"
    case b = "B"

    var omittedPage: Int { self == .a ? 2 : 3 }
    var omittedScreen: String { self == .a ? "labyrinths" : "calm" }
    var paywallMessages: [String] {
        switch self {
        case .a: ["100+ mazes", "Seasonal content every month", "Forever access"]
        case .b: ["No ads", "100+ levels work offline", "Forever access"]
        }
    }

    var analyticsParameters: [String: String] {
        ["experiment_id": OnboardingExperiment.id, "experiment_variant": rawValue,
         "omitted_screen": omittedScreen]
    }
}

enum OnboardingExperiment {
    static let id = "onboarding_benefits_v1"
    static let assignmentKey = "onboardingExperiment.\(id).variant"

    static func assignedVariant(defaults: UserDefaults = .standard,
                                arguments: [String] = ProcessInfo.processInfo.arguments,
                                randomVariant: () -> OnboardingExperimentVariant = { Bool.random() ? .a : .b }) -> OnboardingExperimentVariant {
        if let forced = forcedVariant(arguments: arguments) { return forced }
        if let saved = defaults.string(forKey: assignmentKey).flatMap(OnboardingExperimentVariant.init(rawValue:)) {
            return saved
        }
        let variant = randomVariant()
        defaults.set(variant.rawValue, forKey: assignmentKey)
        return variant
    }

    static func analyticsParameters(defaults: UserDefaults = .standard,
                                    arguments: [String] = ProcessInfo.processInfo.arguments) -> [String: String] {
        let variant = forcedVariant(arguments: arguments)
            ?? defaults.string(forKey: assignmentKey).flatMap(OnboardingExperimentVariant.init(rawValue:))
        return variant?.analyticsParameters ?? [:]
    }

    private static func forcedVariant(arguments: [String]) -> OnboardingExperimentVariant? {
#if DEBUG
        if arguments.contains("-uiTestDisableAnalytics"),
           let index = arguments.firstIndex(of: "-uiTestOnboardingVariant"),
           arguments.indices.contains(index + 1) {
            return OnboardingExperimentVariant(rawValue: arguments[index + 1])
        }
#endif
        return nil
    }
}

class UserPreferences: ObservableObject {
    private let defaults: UserDefaults

    @Published var difficultyLevel: DifficultyLevel {
        didSet { defaults.set(difficultyLevel.rawValue, forKey: "difficultyLevel") }
    }

    @Published var ttsEnabled: Bool {
        didSet { defaults.set(ttsEnabled, forKey: "ttsEnabled") }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: "appLanguage")
            defaults.set(true, forKey: "appLanguageWasSelectedByUser")
        }
    }

    var pathTolerance: CGFloat {
        difficultyLevel.pathTolerance
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let arguments = ProcessInfo.processInfo.arguments
        let isUITestCompletionFlow = arguments.contains("-uiTestShowCompletionForLastLevel")
        let savedLevel = defaults.string(forKey: "difficultyLevel") ?? DifficultyLevel.medium.rawValue
        self.difficultyLevel = isUITestCompletionFlow
            ? .easy
            : (DifficultyLevel(rawValue: savedLevel) ?? .easy)
        self.ttsEnabled = isUITestCompletionFlow ? false : defaults.bool(forKey: "ttsEnabled")
        let hasCompletedOnboarding = isUITestCompletionFlow || defaults.bool(forKey: "hasCompletedOnboarding")
        self.hasCompletedOnboarding = hasCompletedOnboarding

        let savedLanguageValue = defaults.string(forKey: "appLanguage")
        let savedLanguage = savedLanguageValue.flatMap { AppLanguage(rawValue: $0) }
        let appLanguageWasSelectedByUser = defaults.bool(forKey: "appLanguageWasSelectedByUser")
        let deviceLanguage = AppLanguage.fromPreferredLanguages(Locale.preferredLanguages)
        if let savedLanguage,
           appLanguageWasSelectedByUser || hasCompletedOnboarding || savedLanguage != .english {
            self.appLanguage = savedLanguage
        } else {
            self.appLanguage = deviceLanguage
        }
        defaults.set(self.appLanguage.rawValue, forKey: "appLanguage")

        if !isUITestCompletionFlow && !defaults.bool(forKey: "ttsDefaultSet") {
            self.ttsEnabled = true
            defaults.set(true, forKey: "ttsEnabled")
            defaults.set(true, forKey: "ttsDefaultSet")
        }
    }

}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case german = "de"
    case spanish = "es"
    case japanese = "ja"
    case simplifiedChinese = "zh-Hans"
    case korean = "ko"
    case arabic = "ar"
    case swedish = "sv"
    case finnish = "fi"
    case dutch = "nl"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var isRightToLeft: Bool { self == .arabic }
    var audioPackID: String? {
        switch self {
        case .english: nil
        case .german: "audio-de"
        case .spanish: "audio-es"
        case .japanese: "audio-ja"
        case .simplifiedChinese: "audio-zh-Hans"
        case .korean: "audio-ko"
        case .arabic: "audio-ar"
        case .swedish: "audio-sv"
        case .finnish: "audio-fi"
        case .dutch: "audio-nl"
        }
    }

    var speechLanguageIdentifier: String {
        switch self {
        case .english: "en-US"
        case .german: "de-DE"
        case .spanish: "es-ES"
        case .japanese: "ja-JP"
        case .simplifiedChinese: "zh-CN"
        case .korean: "ko-KR"
        case .arabic: "ar-SA"
        case .swedish: "sv-SE"
        case .finnish: "fi-FI"
        case .dutch: "nl-NL"
        }
    }

    var displayName: String {
        switch self {
        case .english: "English"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .japanese: "日本語"
        case .simplifiedChinese: "简体中文"
        case .korean: "한국어"
        case .arabic: "العربية"
        case .swedish: "Svenska"
        case .finnish: "Suomi"
        case .dutch: "Nederlands"
        }
    }

    static func fromPreferredLanguages(_ languages: [String]) -> AppLanguage {
        for language in languages {
            let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
            if normalized == "zh"
                || normalized.hasPrefix("zh-hans")
                || normalized.hasPrefix("zh-cn")
                || normalized.hasPrefix("zh-sg") {
                return .simplifiedChinese
            }
            let code = normalized.split(separator: "-").first.map(String.init) ?? normalized
            if code != "zh", let supportedLanguage = AppLanguage(rawValue: code) {
                return supportedLanguage
            }
        }
        return .english
    }
}

enum DifficultyLevel: String, CaseIterable, Codable {
    case easy, medium, hard

    var displayName: String { rawValue.capitalized }

    var pathTolerance: CGFloat {
        switch self {
        case .easy: return 25
        case .medium: return 18
        case .hard: return 12
        }
    }
}
