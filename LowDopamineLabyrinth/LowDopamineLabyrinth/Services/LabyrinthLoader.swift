import Foundation

class LabyrinthLoader {
    static let shared = LabyrinthLoader()

    private var cachedLabyrinths: [Labyrinth] = []

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

    func loadForDifficulty(_ level: DifficultyLevel) -> [Labyrinth] {
        let all = loadAll()
        let filtered = all.filter { $0.difficulty == level.rawValue }

        // Interleave normal and adventure labyrinths, shifting adventure
        // by half to avoid pairing stories with the same end character
        let normal = filtered.filter { $0.itemRule == nil }
        let adventure = filtered.filter { $0.itemRule != nil }
        let shift = adventure.count / 2

        var result: [Labyrinth] = []
        let maxCount = max(normal.count, adventure.count)
        for i in 0..<maxCount {
            if i < normal.count { result.append(normal[i]) }
            if !adventure.isEmpty {
                let advIndex = (i + shift) % adventure.count
                if i < adventure.count { result.append(adventure[advIndex]) }
            }
        }
        return result
    }

    /// Load story metadata for all stories in the first pack.
    /// Returns `[StoryInfo]` sorted by story number.
    func loadStories() -> [StoryInfo] {
        guard let manifest = loadManifest(),
              let pack = manifest.packs?.first else { return [] }

        let freeStories = pack.freeStories
        let all = loadAll()

        // Group manifest entries by story number
        let entriesByStory = Dictionary(grouping: manifest.labyrinths, by: { $0.story ?? 0 })

        return pack.stories.compactMap { storyNumber -> StoryInfo? in
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

            return StoryInfo(
                number: storyNumber,
                title: firstEntry.title,
                location: firstEntry.location ?? "",
                characterEnd: characterEnd,
                isFree: storyNumber <= freeStories,
                isAdventure: storyNumber >= 11,
                labyrinthIds: labyrinthIds
            )
        }.sorted { $0.number < $1.number }
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
