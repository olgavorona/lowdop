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
        guard let url = Bundle.main.url(forResource: id, withExtension: "json") else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Labyrinth.self, from: data)
    }

    func loadAll() -> [Labyrinth] {
        if !cachedLabyrinths.isEmpty { return cachedLabyrinths }

        guard let manifest = loadManifest() else { return [] }
        cachedLabyrinths = manifest.labyrinths.compactMap { loadLabyrinth(id: $0.id) }
        return cachedLabyrinths
    }

    func loadForAgeGroup(_ ageGroup: AgeGroup) -> [Labyrinth] {
        let all = loadAll()
        let difficulties = Set(ageGroup.difficulties)
        return all.filter { difficulties.contains($0.difficulty) }
    }
}
