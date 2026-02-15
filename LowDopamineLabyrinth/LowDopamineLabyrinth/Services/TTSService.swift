import AVFoundation

class TTSService: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?

    func playAudio(_ filename: String?) -> Bool {
        guard let filename = filename, !filename.isEmpty else { return false }

        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Labyrinths/audio") else {
            // Also try without subdirectory
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
                return false
            }
            return playURL(url)
        }
        return playURL(url)
    }

    private func playURL(_ url: URL) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            return true
        } catch {
            return false
        }
    }

    func speak(_ text: String, rate: Float = 0.45) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.1
        utterance.volume = 0.9
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
