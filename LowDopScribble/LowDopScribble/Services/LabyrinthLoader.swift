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

    /// Load all labyrinths belonging to a pack, sorted by manifest order.
    func loadForPack(packId: String) -> [Labyrinth] {
        let all = loadAll()
        guard let pack = packInfo(packId: packId) else { return [] }
        let storyOrder = Dictionary(uniqueKeysWithValues: pack.stories.enumerated().map { ($0.element, $0.offset) })
        let storySet = Set(pack.stories)
        return all
            .filter { storySet.contains($0.storyNumber) }
            .sorted { lhs, rhs in
                let lhsIndex = storyOrder[lhs.storyNumber] ?? Int.max
                let rhsIndex = storyOrder[rhs.storyNumber] ?? Int.max
                return lhsIndex < rhsIndex
            }
    }

    /// Load story metadata for all stories in a pack.
    func loadStories(packId: String) -> [StoryInfo] {
        guard let manifest = loadManifest(),
              let pack = packInfo(packId: packId) else { return [] }

        let all = loadAll()
        let entriesByStory = Dictionary(grouping: manifest.labyrinths, by: { $0.story ?? 0 })

        return pack.stories.enumerated().compactMap { _, storyNumber -> StoryInfo? in
            guard let entries = entriesByStory[storyNumber],
                  let firstEntry = entries.first else { return nil }

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
                isFree: true,
                isAdventure: isAdventure,
                labyrinthIds: labyrinthIds
            )
        }
    }
}
