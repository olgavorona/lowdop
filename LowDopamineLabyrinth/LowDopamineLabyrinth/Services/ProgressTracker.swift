import Foundation

class ProgressTracker: ObservableObject {
    private let defaults = UserDefaults.standard
    private let completedKey = "completedLabyrinths"

    @Published var completedIds: Set<String>

    init() {
        let saved = defaults.stringArray(forKey: completedKey) ?? []
        self.completedIds = Set(saved)
    }

    @discardableResult
    func markCompleted(_ id: String) -> Bool {
        let wasInserted = completedIds.insert(id).inserted
        defaults.set(Array(completedIds), forKey: completedKey)
        return wasInserted
    }

    func isCompleted(_ id: String) -> Bool {
        completedIds.contains(id)
    }

    func hasCompletedAny(in labyrinthIds: [String]) -> Bool {
        labyrinthIds.contains { completedIds.contains($0) }
    }

    func completedCount(in labyrinths: [Labyrinth]) -> Int {
        labyrinths.filter { completedIds.contains($0.id) }.count
    }

    func completedStoryCount(in stories: [StoryInfo]) -> Int {
        stories.filter { hasCompletedAny(in: $0.labyrinthIds) }.count
    }
}
