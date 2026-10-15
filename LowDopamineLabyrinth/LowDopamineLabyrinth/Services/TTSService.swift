import AVFoundation

@MainActor
class TTSService: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var language: AppLanguage = .english

    func setLanguage(_ language: AppLanguage) {
        self.language = language
    }

    @discardableResult
    func playAudio(_ filename: String?) -> Bool {
        guard let filename = filename, !filename.isEmpty else { return false }

        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        if language != .english,
           let localizedURL = LanguageAudioPackManager.shared.audioURL(for: filename, language: language) {
            if playURL(localizedURL) { return true }
        }
        if playBundledAudio(named: name, ext: ext, subdirectory: "audio") { return true }

        guard filename == "onboarding_trace_intro.mp3" else { return false }
        let instruction = LabyrinthLoader.shared.localizedNarration(
            "Draw the path with your finger or Apple Pencil. Start at the green go marker."
        )
        return speak(instruction)
    }

    @discardableResult
    func playBundledAudio(named name: String, ext: String = "mp3", subdirectory: String? = "audio") -> Bool {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) else {
            return false
        }
        return playURL(url)
    }

    func prepareAudio(for labyrinth: Labyrinth) {
        // Narration uses the selected language pack when it is downloaded,
        // with the bundled English track as the offline fallback.
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
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

    private func speak(_ text: String) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[TTSService] Could not activate audio session for speech: \(error)")
            return false
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.rawValue)
        speechSynthesizer.speak(utterance)
        return true
    }
}
