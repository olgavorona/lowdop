import Foundation

class UserPreferences: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var ttsEnabled: Bool {
        didSet { defaults.set(ttsEnabled, forKey: "ttsEnabled") }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    init() {
        self.ttsEnabled = defaults.bool(forKey: "ttsEnabled")
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")

        if !defaults.bool(forKey: "ttsDefaultSet") {
            self.ttsEnabled = true
            defaults.set(true, forKey: "ttsEnabled")
            defaults.set(true, forKey: "ttsDefaultSet")
        }
    }
}
