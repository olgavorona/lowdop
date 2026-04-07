import SwiftUI

class GameViewModel: ObservableObject {
    @Published var labyrinths: [Labyrinth] = []
    @Published var currentIndex: Int = 0
    @Published var showPaywall: Bool = false
    @Published var isPlaying: Bool = false

    private(set) var currentPackId: String = "ocean_adventures"
    private(set) var currentPackFreeStories: Int = 3

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

    func loadLabyrinths(packId: String = "ocean_adventures") {
        currentPackId = packId
        currentPackFreeStories = LabyrinthLoader.shared.packInfo(packId: packId)?.freeStories ?? 0
        labyrinths = LabyrinthLoader.shared.loadForDifficulty(preferences.difficultyLevel, packId: packId)
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
        }
    }

    // MARK: - Story Locking

    /// Extracts the story number from a labyrinth ID (e.g., "denny_005_easy" -> 5)
    func storyNumber(for labyrinth: Labyrinth) -> Int? {
        let parts = labyrinth.id.split(separator: "_")
        guard parts.count >= 2, let number = Int(parts[1]) else { return nil }
        return number
    }

    /// Returns true if the story falls beyond the current pack's free-story allowance.
    func isStoryLocked(_ storyNumber: Int) -> Bool {
        guard !isPremium else { return false }
        let packStories = LabyrinthLoader.shared.packInfo(packId: currentPackId)?.stories ?? []
        guard let storyIndex = packStories.firstIndex(of: storyNumber) else { return true }
        return storyIndex >= currentPackFreeStories
    }

    func isLabyrinthLocked(at index: Int) -> Bool {
        index >= currentPackFreeStories && !isPremium
    }

    /// Checks whether all 3 difficulty levels of the current labyrinth's story are completed
    var isStoryComplete: Bool {
        guard let lab = currentLabyrinth,
              let story = storyNumber(for: lab) else { return false }
        let paddedStory = String(format: "%03d", story)
        let easyId = "denny_\(paddedStory)_easy"
        let mediumId = "denny_\(paddedStory)_medium"
        let hardId = "denny_\(paddedStory)_hard"
        return progressTracker.completedIds.contains(easyId)
            && progressTracker.completedIds.contains(mediumId)
            && progressTracker.completedIds.contains(hardId)
    }
}
