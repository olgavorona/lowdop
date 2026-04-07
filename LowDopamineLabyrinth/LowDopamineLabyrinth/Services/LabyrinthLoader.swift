import Foundation

class LabyrinthLoader {
    static let shared = LabyrinthLoader()

    private var cachedLabyrinths: [Labyrinth] = []

    func packInfo(packId: String) -> PackInfo? {
        loadManifest()?.packs?.first(where: { $0.id == packId })
    }

    func loadManifest() -> LabyrinthManifest? {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json") else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LabyrinthManifest.self, from: data)
    }

    func loadLabyrinth(id: String) -> Labyrinth? {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json") else {
            print("[LabyrinthLoader] Missing resource: \(id).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Labyrinth.self, from: data)
        } catch {
            print("[LabyrinthLoader] Failed to decode \(id).json: \(error)")
            return nil
        }
    }

    func loadAll() -> [Labyrinth] {
        if !cachedLabyrinths.isEmpty { return cachedLabyrinths }

        guard let manifest = loadManifest() else { return [] }
        cachedLabyrinths = manifest.labyrinths.compactMap { loadLabyrinth(id: $0.id) }
        return cachedLabyrinths
    }

    func loadForDifficulty(_ level: DifficultyLevel, packId: String = "ocean_adventures") -> [Labyrinth] {
        let all = loadAll()
        guard let pack = packInfo(packId: packId) else {
            return []
        }
        let storyOrder = Dictionary(uniqueKeysWithValues: pack.stories.enumerated().map { ($0.element, $0.offset) })
        let storySet = Set(pack.stories)
        let packLabyrinths = all.filter { storySet.contains($0.storyNumber) }

        // Prefer exact difficulty match; fall back to closest available if the pack
        // doesn't have variants for the selected difficulty (e.g. a test pack with medium only).
        let difficultyOrder: [DifficultyLevel] = [.medium, .easy, .hard]
        let fallbackOrder = ([level] + difficultyOrder.filter { $0 != level })
        let resolvedDifficulty = fallbackOrder.first { d in
            packLabyrinths.contains { $0.difficulty == d.rawValue }
        } ?? level

        return packLabyrinths
            .filter { $0.difficulty == resolvedDifficulty.rawValue }
            .sorted { lhs, rhs in
                let lhsIndex = storyOrder[lhs.storyNumber] ?? Int.max
                let rhsIndex = storyOrder[rhs.storyNumber] ?? Int.max
                if lhsIndex != rhsIndex {
                    return lhsIndex < rhsIndex
                }
                let difficultyOrder = ["easy": 0, "medium": 1, "hard": 2]
                return (difficultyOrder[lhs.difficulty] ?? 99) < (difficultyOrder[rhs.difficulty] ?? 99)
            }
    }

    /// Load story metadata for all stories in a pack.
    /// Returns `[StoryInfo]` in the manifest-defined pack order.
    func loadStories(packId: String = "ocean_adventures") -> [StoryInfo] {
        guard let manifest = loadManifest(),
              let pack = packInfo(packId: packId) else { return [] }

        let freeStories = pack.freeStories
        let all = loadAll()

        // Group manifest entries by story number
        let entriesByStory = Dictionary(grouping: manifest.labyrinths, by: { $0.story ?? 0 })

        return pack.stories.enumerated().compactMap { index, storyNumber -> StoryInfo? in
            guard let entries = entriesByStory[storyNumber],
                  let firstEntry = entries.first else { return nil }

            // Determine characterEnd by loading the first labyrinth for this story
            let characterEnd: String
            if let labyrinth = all.first(where: { $0.storyNumber == storyNumber }) {
                characterEnd = labyrinth.characterEnd.imageAsset ?? labyrinth.characterEnd.name ?? labyrinth.characterEnd.type
            } else {
                characterEnd = ""
            }

            let labyrinthIds = entries.map { $0.id }
            let isAdventure = all.contains { $0.storyNumber == storyNumber && $0.itemRule != nil }

            return StoryInfo(
                number: storyNumber,
                title: firstEntry.title,
                location: firstEntry.location ?? "",
                characterEnd: characterEnd,
                isFree: index < freeStories,
                isAdventure: isAdventure,
                labyrinthIds: labyrinthIds
            )
        }
    }

    /// Load a single labyrinth matching both story number and difficulty.
    func loadForStory(storyNumber: Int, difficulty: DifficultyLevel) -> Labyrinth? {
        guard let manifest = loadManifest() else { return nil }

        let entry = manifest.labyrinths.first {
            $0.story == storyNumber && $0.difficulty == difficulty.rawValue
        }

        guard let id = entry?.id else { return nil }
        return loadLabyrinth(id: id)
    }

    /// Load all 3 difficulty variants for one story (easy, medium, hard).
    /// Returns `[Labyrinth]` sorted by difficulty order: easy first, hard last.
    func loadAllForStory(storyNumber: Int) -> [Labyrinth] {
        guard let manifest = loadManifest() else { return [] }

        let difficultyOrder = ["easy", "medium", "hard"]
        let entries = manifest.labyrinths.filter { $0.story == storyNumber }
        let labyrinths = entries.compactMap { loadLabyrinth(id: $0.id) }

        return labyrinths.sorted { a, b in
            let aIndex = difficultyOrder.firstIndex(of: a.difficulty) ?? Int.max
            let bIndex = difficultyOrder.firstIndex(of: b.difficulty) ?? Int.max
            return aIndex < bIndex
        }
    }
}
