import Foundation

class UserPreferences: ObservableObject {
    private let defaults = UserDefaults.standard

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

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITestCompletionFlow = arguments.contains("-uiTestShowCompletionForLastLevel")
        let savedLevel = defaults.string(forKey: "difficultyLevel") ?? DifficultyLevel.easy.rawValue
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

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var audioPackID: String? {
        switch self {
        case .english: nil
        case .german: "audio-de"
        case .spanish: "audio-es"
        }
    }

    var displayName: String {
        switch self {
        case .english: "English"
        case .german: "Deutsch"
        case .spanish: "Español"
        }
    }

    static func fromPreferredLanguages(_ languages: [String]) -> AppLanguage {
        for language in languages {
            let code = String(language.prefix { $0.isLetter }).lowercased()
            if let supportedLanguage = AppLanguage(rawValue: code) {
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
