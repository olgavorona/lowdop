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

    var totalFreeLabyrinthsPlayed: Int {
        get { defaults.integer(forKey: "totalFreeLabyrinthsPlayed") }
        set { defaults.set(newValue, forKey: "totalFreeLabyrinthsPlayed") }
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
        // First 3 labyrinths are always free, no daily limit
        if totalFreeLabyrinthsPlayed < 3 { return true }
        // After 3 total: 1 per day
        guard let lastPlayed = lastPlayedTimestamp else { return true }
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastPlayed) {
            dailyLabyrinthsPlayed = 0
            return true
        }
        return dailyLabyrinthsPlayed < 1
    }

    func recordPlay() {
        let calendar = Calendar.current
        if let lastPlayed = lastPlayedTimestamp, !calendar.isDateInToday(lastPlayed) {
            dailyLabyrinthsPlayed = 1
        } else {
            dailyLabyrinthsPlayed += 1
        }
        totalFreeLabyrinthsPlayed += 1
        // When initial free plays are exhausted, reset daily counter
        // so the 1-per-day limit starts fresh
        if totalFreeLabyrinthsPlayed == 3 {
            dailyLabyrinthsPlayed = 0
        }
        lastPlayedTimestamp = Date()
    }

    /// Returns remaining free plays for UI display. nil = unlimited (premium).
    func freeLabyrinthsRemaining(isPremium: Bool) -> Int? {
        if isPremium { return nil }
        if totalFreeLabyrinthsPlayed < 3 {
            return 3 - totalFreeLabyrinthsPlayed
        }
        // After initial 3: daily limit
        guard let lastPlayed = lastPlayedTimestamp else { return 1 }
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastPlayed) { return 1 }
        return max(0, 1 - dailyLabyrinthsPlayed)
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
