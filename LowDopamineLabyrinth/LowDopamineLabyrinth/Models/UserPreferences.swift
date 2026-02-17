import Foundation

class UserPreferences: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var ageGroup: AgeGroup {
        didSet { defaults.set(ageGroup.rawValue, forKey: "ageGroup") }
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
        ageGroup == .young ? 20 : 15
    }

    init() {
        let savedAge = defaults.string(forKey: "ageGroup") ?? AgeGroup.young.rawValue
        self.ageGroup = AgeGroup(rawValue: savedAge) ?? .young
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

enum AgeGroup: String, CaseIterable {
    case young = "3-4"
    case older = "5-6"

    var displayName: String {
        switch self {
        case .young: return "3-4"
        case .older: return "5-6"
        }
    }

    var difficulties: [String] {
        switch self {
        case .young: return ["easy"]
        case .older: return ["medium", "hard"]
        }
    }
}
