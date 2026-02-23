import AVFoundation

class TTSService: ObservableObject {
    private var audioPlayer: AVAudioPlayer?

    private static let audioBaseURL = "https://lowdop-audio.cdn.example.com/labyrinths/audio/"

    private static var cacheDir: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("labyrinth_audio")
    }

    @discardableResult
    func playAudio(_ filename: String?) -> Bool {
        guard let filename = filename, !filename.isEmpty else { return false }

        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        // 1. Check bundle (folder reference copies as "audio/" at bundle root)
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "audio") {
            return playURL(url)
        }

        // 2. Check cache directory
        let cached = Self.cacheDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: cached.path) {
            return playURL(cached)
        }

        return false
    }

    func prepareAudio(for labyrinth: Labyrinth) {
        downloadIfNeeded(labyrinth.audioInstruction)
        downloadIfNeeded(labyrinth.audioCompletion)
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Private

    private func playURL(_ url: URL) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            return true
        } catch {
            print("[TTSService] Failed to play \(url.lastPathComponent): \(error)")
            return false
        }
    }

    private func downloadIfNeeded(_ filename: String?) {
        guard let filename = filename, !filename.isEmpty else { return }

        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        // Already in bundle — nothing to do
        if Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "audio") != nil {
            return
        }

        let cached = Self.cacheDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: cached.path) { return }

        // Fire-and-forget background download
        guard let remote = URL(string: Self.audioBaseURL + filename) else { return }
        URLSession.shared.dataTask(with: remote) { data, response, _ in
            guard let data = data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return }
            try? FileManager.default.createDirectory(at: Self.cacheDir, withIntermediateDirectories: true)
            try? data.write(to: cached)
        }.resume()
    }
}
