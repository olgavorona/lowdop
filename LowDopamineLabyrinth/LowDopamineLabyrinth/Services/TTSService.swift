import AVFoundation

class TTSService: ObservableObject {
    private var audioPlayer: AVAudioPlayer?

    @discardableResult
    func playAudio(_ filename: String?) -> Bool {
        guard let filename = filename, !filename.isEmpty else { return false }

        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        // Check bundle (folder reference copies as "audio/" at bundle root)
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "audio") {
            return playURL(url)
        }

        return false
    }

    func prepareAudio(for labyrinth: Labyrinth) {
        // All audio is bundled — no preparation needed
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
}
