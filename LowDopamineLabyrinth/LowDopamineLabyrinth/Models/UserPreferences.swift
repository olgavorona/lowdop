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

    var pathTolerance: CGFloat {
        difficultyLevel.pathTolerance
    }

    init() {
        let savedLevel = defaults.string(forKey: "difficultyLevel") ?? DifficultyLevel.easy.rawValue
        self.difficultyLevel = DifficultyLevel(rawValue: savedLevel) ?? .easy
        self.ttsEnabled = defaults.bool(forKey: "ttsEnabled")
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")

        if !defaults.bool(forKey: "ttsDefaultSet") {
            self.ttsEnabled = true
            defaults.set(true, forKey: "ttsEnabled")
            defaults.set(true, forKey: "ttsDefaultSet")
        }
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
