import SwiftUI

class GameViewModel: ObservableObject {
    @Published var labyrinths: [Labyrinth] = []
    @Published var currentIndex: Int = 0
    @Published var showPaywall: Bool = false

    let preferences: UserPreferences
    let subscriptionManager: SubscriptionManager
    let progressTracker: ProgressTracker

    var currentLabyrinth: Labyrinth? {
        guard currentIndex >= 0 && currentIndex < labyrinths.count else { return nil }
        return labyrinths[currentIndex]
    }

    var progressText: String {
        "\(currentIndex + 1) / \(labyrinths.count)"
    }

    init(preferences: UserPreferences,
         subscriptionManager: SubscriptionManager,
         progressTracker: ProgressTracker) {
        self.preferences = preferences
        self.subscriptionManager = subscriptionManager
        self.progressTracker = progressTracker
    }

    func loadLabyrinths() {
        labyrinths = LabyrinthLoader.shared.loadForAgeGroup(preferences.ageGroup)
        currentIndex = 0
    }

    func nextLabyrinth() {
        guard canProceed() else {
            showPaywall = true
            return
        }
        if currentIndex < labyrinths.count - 1 {
            currentIndex += 1
        }
    }

    func previousLabyrinth() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }

    func completeCurrentLabyrinth() {
        if let lab = currentLabyrinth {
            progressTracker.markCompleted(lab.id)
            preferences.recordPlay()
        }
    }

    func canProceed() -> Bool {
        preferences.canPlayToday(isPremium: subscriptionManager.isPremium)
    }
}
