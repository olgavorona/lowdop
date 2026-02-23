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

    var lastPlayedTimestamp: Date? {
        get { defaults.object(forKey: "lastPlayedTimestamp") as? Date }
        set { defaults.set(newValue, forKey: "lastPlayedTimestamp") }
    }

    var dailyLabyrinthsPlayed: Int {
        get { defaults.integer(forKey: "dailyLabyrinthsPlayed") }
        set { defaults.set(newValue, forKey: "dailyLabyrinthsPlayed") }
    }

    var pathTolerance: CGFloat {
        difficultyLevel.pathTolerance
    }

    init() {
        let savedLevel = defaults.string(forKey: "difficultyLevel") ?? DifficultyLevel.beginner.rawValue
        self.difficultyLevel = DifficultyLevel(rawValue: savedLevel) ?? .beginner
        self.ttsEnabled = defaults.bool(forKey: "ttsEnabled")
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")

        if !defaults.bool(forKey: "ttsDefaultSet") {
            self.ttsEnabled = true
            defaults.set(true, forKey: "ttsEnabled")
            defaults.set(true, forKey: "ttsDefaultSet")
        }
    }

    func canPlayToday(isPremium: Bool) -> Bool {
        if isPremium { return true }
        guard let lastPlayed = lastPlayedTimestamp else { return true }
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastPlayed) {
            dailyLabyrinthsPlayed = 0
            return true
        }
        return dailyLabyrinthsPlayed < 1
    }

    func recordPlay() {
        lastPlayedTimestamp = Date()
        let calendar = Calendar.current
        if let lastPlayed = lastPlayedTimestamp, !calendar.isDateInToday(lastPlayed) {
            dailyLabyrinthsPlayed = 1
        } else {
            dailyLabyrinthsPlayed += 1
        }
    }
}

enum DifficultyLevel: String, CaseIterable {
    case beginner, easy, medium, hard, expert

    var displayName: String { rawValue.capitalized }

    var pathTolerance: CGFloat {
        switch self {
        case .beginner: return 25
        case .easy: return 22
        case .medium: return 18
        case .hard: return 15
        case .expert: return 12
        }
    }
}
