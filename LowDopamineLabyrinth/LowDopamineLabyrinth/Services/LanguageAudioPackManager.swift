import BackgroundAssets
import Combine
import Foundation
import System

@MainActor
final class LanguageAudioPackManager: ObservableObject {
    static let shared = LanguageAudioPackManager()

    @Published private(set) var progress: [AppLanguage: Double] = [:]
    @Published private(set) var downloadedLanguages: Set<AppLanguage> = []
    @Published private(set) var errors: [AppLanguage: String] = [:]

    private init() {}

    private var usesLocalMockServer: Bool {
#if targetEnvironment(simulator) && DEBUG
        ProcessInfo.processInfo.arguments.contains("-useLocalAudioMockServer")
#else
        false
#endif
    }

    private var mockAudioRoot: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MockLanguageAudio", isDirectory: true)
    }

    func refreshStatus(for language: AppLanguage) async {
#if targetEnvironment(simulator)
        guard usesLocalMockServer else { return }
        let folder = mockAudioRoot.appendingPathComponent(language.rawValue, isDirectory: true)
        let completionMarker = folder.appendingPathComponent(".download-complete")
        let isDownloaded = FileManager.default.fileExists(atPath: completionMarker.path)
        if isDownloaded { downloadedLanguages.insert(language) }
        else { downloadedLanguages.remove(language) }
        Analytics.send("Language.audioPackStatusChecked", with: [
            "language": language.rawValue,
            "downloaded": String(isDownloaded),
            "source": "local_mock_server",
            "app_locale": language.rawValue
        ])
#else
        guard let packID = language.audioPackID else { return }
        do {
            let status = try await AssetPackManager.shared.status(ofAssetPackWithID: packID)
            let isDownloaded = status.contains(.downloaded)
            if isDownloaded {
                downloadedLanguages.insert(language)
            } else {
                downloadedLanguages.remove(language)
            }
            Analytics.send("Language.audioPackStatusChecked", with: [
                "language": language.rawValue,
                "downloaded": String(isDownloaded),
                "app_locale": language.rawValue
            ])
        } catch {
            downloadedLanguages.remove(language)
            Analytics.send("Language.audioPackStatusCheckFailed", with: [
                "language": language.rawValue,
                "app_locale": language.rawValue
            ])
        }
#endif
    }

    func download(_ language: AppLanguage) async {
#if targetEnvironment(simulator)
        guard usesLocalMockServer else {
            errors[language] = "Audio pack downloads are unavailable in Simulator."
            Analytics.send("Language.audioPackDownloadFailed", with: [
                "language": language.rawValue,
                "app_locale": language.rawValue,
                "reason": "simulator_unavailable"
            ])
            return
        }
        errors[language] = nil
        progress[language] = 0
        Analytics.send("Language.audioPackDownloadStarted", with: [
            "language": language.rawValue,
            "source": "local_mock_server",
            "app_locale": language.rawValue
        ])
        do {
            try await downloadFromLocalMockServer(language)
            progress[language] = nil
            downloadedLanguages.insert(language)
            Analytics.send("Language.audioPackDownloadSucceeded", with: [
                "language": language.rawValue,
                "source": "local_mock_server",
                "app_locale": language.rawValue
            ])
        } catch {
            progress[language] = nil
            errors[language] = "Could not download this audio pack. Please try again."
            Analytics.send("Language.audioPackDownloadFailed", with: [
                "language": language.rawValue,
                "source": "local_mock_server",
                "app_locale": language.rawValue
            ])
            Analytics.error("LanguageAudio.mockDownload", message: error.localizedDescription, parameters: [
                "language": language.rawValue,
                "source": "local_mock_server"
            ])
        }
        return
#else
        guard let packID = language.audioPackID else { return }
        errors[language] = nil
        progress[language] = 0
        Analytics.send("Language.audioPackDownloadStarted", with: [
            "language": language.rawValue,
            "app_locale": language.rawValue
        ])
        var progressTask: Task<Void, Never>?

        do {
            let manager = AssetPackManager.shared
            let pack = try await manager.assetPack(withID: packID)
            let updates = manager.statusUpdates(forAssetPackWithID: packID)
            progressTask = Task { @MainActor in
                for await update in updates {
                    if case .downloading(_, let downloadProgress) = update {
                        self.progress[language] = downloadProgress.fractionCompleted
                    }
                }
            }

            try await manager.ensureLocalAvailability(of: pack)
            progressTask?.cancel()
            progress[language] = nil
            downloadedLanguages.insert(language)
            Analytics.send("Language.audioPackDownloadSucceeded", with: [
                "language": language.rawValue,
                "app_locale": language.rawValue
            ])
        } catch {
            progressTask?.cancel()
            progress[language] = nil
            errors[language] = "Could not download this audio pack. Please try again."
            let nsError = error as NSError
            Analytics.send("Language.audioPackDownloadFailed", with: [
                "language": language.rawValue,
                "app_locale": language.rawValue,
                "error_domain": nsError.domain,
                "error_code": String(nsError.code)
            ])
            Analytics.error("LanguageAudio.assetPackDownload", message: nsError.localizedDescription, parameters: [
                "language": language.rawValue,
                "error_domain": nsError.domain,
                "error_code": String(nsError.code)
            ])
            print(
                "[LanguageAudioPackManager] Download failed for \(packID): " +
                "domain=\(nsError.domain), code=\(nsError.code), " +
                "description=\(nsError.localizedDescription), userInfo=\(nsError.userInfo)"
            )
        }
#endif
    }

    func remove(_ language: AppLanguage) async {
#if targetEnvironment(simulator)
        guard usesLocalMockServer else {
            errors[language] = "Audio pack downloads are unavailable in Simulator."
            Analytics.send("Language.audioPackRemovalFailed", with: [
                "language": language.rawValue,
                "app_locale": language.rawValue,
                "reason": "simulator_unavailable"
            ])
            return
        }
        do {
            let folder = mockAudioRoot.appendingPathComponent(language.rawValue, isDirectory: true)
            try FileManager.default.removeItem(at: folder)
            downloadedLanguages.remove(language)
            errors[language] = nil
            Analytics.send("Language.audioPackRemoved", with: [
                "language": language.rawValue,
                "source": "local_mock_server",
                "app_locale": language.rawValue
            ])
        } catch {
            errors[language] = "Could not remove this audio pack. Please try again."
            Analytics.error("LanguageAudio.mockRemoval", message: error.localizedDescription, parameters: [
                "language": language.rawValue,
                "source": "local_mock_server"
            ])
        }
        return
#else
        guard let packID = language.audioPackID else { return }
        do {
            try await AssetPackManager.shared.remove(assetPackWithID: packID)
            downloadedLanguages.remove(language)
            errors[language] = nil
            Analytics.send("Language.audioPackRemoved", with: [
                "language": language.rawValue,
                "app_locale": language.rawValue
            ])
        } catch {
            errors[language] = "Could not remove this audio pack. Please try again."
            Analytics.send("Language.audioPackRemovalFailed", with: [
                "language": language.rawValue,
                "app_locale": language.rawValue
            ])
        }
#endif
    }

    func audioURL(for filename: String, language: AppLanguage) -> URL? {
#if targetEnvironment(simulator)
        guard usesLocalMockServer, downloadedLanguages.contains(language) else { return nil }
        let url = mockAudioRoot.appendingPathComponent(language.rawValue, isDirectory: true)
            .appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
#else
        guard language.audioPackID != nil,
              downloadedLanguages.contains(language) else { return nil }
        return try? AssetPackManager.shared.url(
            for: FilePath("\(language.rawValue)/audio/\(filename)")
        )
#endif
    }

#if targetEnvironment(simulator)
    private func downloadFromLocalMockServer(_ language: AppLanguage) async throws {
        let configuredBaseURL = ProcessInfo.processInfo.environment["LOCAL_AUDIO_MOCK_SERVER"] ?? "http://127.0.0.1:8765"
        let baseURL = configuredBaseURL.hasSuffix("/") ? String(configuredBaseURL.dropLast()) : configuredBaseURL
        guard let manifestURL = URL(string: "\(baseURL)/\(language.rawValue)/manifest.json") else {
            throw URLError(.badURL)
        }
        let (manifestData, response) = try await URLSession.shared.data(from: manifestURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let filenames = try JSONDecoder().decode([String].self, from: manifestData)
        guard !filenames.isEmpty else { throw URLError(.zeroByteResource) }

        let destination = mockAudioRoot.appendingPathComponent(language.rawValue, isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for (index, filename) in filenames.enumerated() {
            guard !filename.contains("/") && !filename.contains("..") else { continue }
            guard let fileURL = URL(string: "\(baseURL)/\(language.rawValue)/audio/\(filename)") else {
                throw URLError(.badURL)
            }
            let (data, fileResponse) = try await URLSession.shared.data(from: fileURL)
            guard (fileResponse as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            try data.write(to: destination.appendingPathComponent(filename), options: .atomic)
            progress[language] = Double(index + 1) / Double(filenames.count)
        }
        try Data().write(to: destination.appendingPathComponent(".download-complete"), options: .atomic)
    }
#endif
}
