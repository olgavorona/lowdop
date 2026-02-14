import Foundation

class ProgressTracker: ObservableObject {
    private let defaults = UserDefaults.standard
    private let completedKey = "completedLabyrinths"

    @Published var completedIds: Set<String>

    init() {
        let saved = defaults.stringArray(forKey: completedKey) ?? []
        self.completedIds = Set(saved)
    }

    func markCompleted(_ id: String) {
        completedIds.insert(id)
        defaults.set(Array(completedIds), forKey: completedKey)
    }

    func isCompleted(_ id: String) -> Bool {
        completedIds.contains(id)
    }

    func completedCount(in labyrinths: [Labyrinth]) -> Int {
        labyrinths.filter { completedIds.contains($0.id) }.count
    }
}
