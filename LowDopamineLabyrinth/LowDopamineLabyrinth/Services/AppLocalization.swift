import Foundation

enum AppLocalization {
    private static let copy: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "ui-localizations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) else {
            return [:]
        }
        return decoded
    }()

    private static var languageCode: String {
        UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    }

    static func text(_ source: String, replacing values: [String: String] = [:]) -> String {
        var result = copy[languageCode]?[source] ?? source
        for (placeholder, value) in values {
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        return result
    }
}
