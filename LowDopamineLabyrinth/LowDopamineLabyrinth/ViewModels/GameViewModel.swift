import SwiftUI

class GameViewModel: ObservableObject {
    @Published var labyrinths: [Labyrinth] = []
    @Published var currentIndex: Int = 0
    @Published var showPaywall: Bool = false
    @Published var selectedLabyrinth: Labyrinth?

    let preferences: UserPreferences
    let subscriptionManager: SubscriptionManager
    let progressTracker: ProgressTracker

    var currentLabyrinth: Labyrinth? {
        guard currentIndex >= 0 && currentIndex < labyrinths.count else { return nil }
        return labyrinths[currentIndex]
    }

    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
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
        selectedLabyrinth = nil
    }

    func selectLabyrinth(_ labyrinth: Labyrinth) {
        if let idx = labyrinths.firstIndex(where: { $0.id == labyrinth.id }) {
            currentIndex = idx
        }
        selectedLabyrinth = labyrinth
    }

    func closeGame() {
        selectedLabyrinth = nil
    }

    func nextLabyrinth() {
        guard canProceed() else {
            showPaywall = true
            return
        }
        if currentIndex < labyrinths.count - 1 {
            currentIndex += 1
            selectedLabyrinth = currentLabyrinth
        }
    }

    func previousLabyrinth() {
        if currentIndex > 0 {
            currentIndex -= 1
            selectedLabyrinth = currentLabyrinth
        }
    }

    func completeCurrentLabyrinth() {
        if let lab = currentLabyrinth {
            progressTracker.markCompleted(lab.id)
            preferences.recordPlay()
        }
    }

    func canProceed() -> Bool {
        if isSimulator { return true }
        return preferences.canPlayToday(isPremium: subscriptionManager.isPremium)
    }
}
