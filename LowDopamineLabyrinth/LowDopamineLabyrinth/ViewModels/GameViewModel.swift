import SwiftUI

class GameViewModel: ObservableObject {
    @Published var labyrinths: [Labyrinth] = []
    @Published var currentIndex: Int = 0
    @Published var showPaywall: Bool = false
    @Published var isPlaying: Bool = false

    let preferences: UserPreferences
    let subscriptionManager: SubscriptionManager
    let progressTracker: ProgressTracker

    var currentLabyrinth: Labyrinth? {
        guard currentIndex >= 0 && currentIndex < labyrinths.count else { return nil }
        return labyrinths[currentIndex]
    }

    var isPremium: Bool {
        subscriptionManager.isPremium
    }

    init(preferences: UserPreferences,
         subscriptionManager: SubscriptionManager,
         progressTracker: ProgressTracker) {
        self.preferences = preferences
        self.subscriptionManager = subscriptionManager
        self.progressTracker = progressTracker
    }

    func loadLabyrinths() {
        labyrinths = LabyrinthLoader.shared.loadForDifficulty(preferences.difficultyLevel)
        currentIndex = 0
        isPlaying = false
    }

    func selectLabyrinth(_ labyrinth: Labyrinth) {
        if let idx = labyrinths.firstIndex(where: { $0.id == labyrinth.id }) {
            currentIndex = idx
            isPlaying = true
        }
    }

    func closeGame() {
        isPlaying = false
    }

    func nextLabyrinth() {
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
        return preferences.canPlayToday(isPremium: subscriptionManager.isPremium)
    }
}
