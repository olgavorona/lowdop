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
}
