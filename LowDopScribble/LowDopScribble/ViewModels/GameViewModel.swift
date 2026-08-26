import SwiftUI

class GameViewModel: ObservableObject {
    @Published var labyrinths: [Labyrinth] = []
    @Published var currentIndex: Int = 0
    @Published var isPlaying: Bool = false

    private(set) var currentPackId: String = "letters"

    let preferences: UserPreferences
    let progressTracker: ProgressTracker

    var currentLabyrinth: Labyrinth? {
        guard currentIndex >= 0 && currentIndex < labyrinths.count else { return nil }
        return labyrinths[currentIndex]
    }

    var isLastLabyrinthInPack: Bool {
        !labyrinths.isEmpty && currentIndex >= labyrinths.count - 1
    }

    init(preferences: UserPreferences, progressTracker: ProgressTracker) {
        self.preferences = preferences
        self.progressTracker = progressTracker
    }

    func loadLabyrinths(packId: String = "letters") {
        currentPackId = packId
        labyrinths = LabyrinthLoader.shared.loadForPack(packId: packId)
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

    func storyNumber(for labyrinth: Labyrinth) -> Int? {
        let parts = labyrinth.id.split(separator: "_")
        guard parts.count >= 2, let number = Int(parts[1]) else { return nil }
        return number
    }

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
