import XCTest
@testable import LowDopamineLabyrinth

class IsolatedPreferencesTestCase: XCTestCase {
    private var suiteName: String!
    var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.lowdopamine.labyrinth.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }
}

final class UserPreferencesTests: IsolatedPreferencesTestCase {

    // MARK: - DifficultyLevel Enum Tests

    func testDifficultyLevelHasExactlyThreeCases() {
        XCTAssertEqual(DifficultyLevel.allCases.count, 3)
        XCTAssertTrue(DifficultyLevel.allCases.contains(.easy))
        XCTAssertTrue(DifficultyLevel.allCases.contains(.medium))
        XCTAssertTrue(DifficultyLevel.allCases.contains(.hard))
    }

    func testPathToleranceValues() {
        XCTAssertEqual(DifficultyLevel.easy.pathTolerance, 25)
        XCTAssertEqual(DifficultyLevel.medium.pathTolerance, 18)
        XCTAssertEqual(DifficultyLevel.hard.pathTolerance, 12)
    }

    func testDifficultyLevelDisplayName() {
        XCTAssertEqual(DifficultyLevel.easy.displayName, "Easy")
        XCTAssertEqual(DifficultyLevel.medium.displayName, "Medium")
        XCTAssertEqual(DifficultyLevel.hard.displayName, "Hard")
    }

    func testDifficultyLevelCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for level in DifficultyLevel.allCases {
            let data = try encoder.encode(level)
            let decoded = try decoder.decode(DifficultyLevel.self, from: data)
            XCTAssertEqual(decoded, level, "Round-trip failed for \(level)")
        }
    }

    // MARK: - UserDefaults Fallback Tests

    func testFallbackForUnknownDifficultyRawValue() {
        defaults.set("beginner", forKey: "difficultyLevel")
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.difficultyLevel, .easy, "Unknown rawValue 'beginner' should fall back to .easy")
    }

    func testFallbackForExpertDifficultyRawValue() {
        defaults.set("expert", forKey: "difficultyLevel")
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.difficultyLevel, .easy, "Unknown rawValue 'expert' should fall back to .easy")
    }

    func testValidDifficultyRawValueLoadsCorrectly() {
        defaults.set("hard", forKey: "difficultyLevel")
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.difficultyLevel, .hard, "Valid rawValue 'hard' should load correctly")
    }

    // MARK: - pathTolerance on UserPreferences

    func testPathToleranceDelegatesToDifficultyLevel() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.difficultyLevel = .medium
        XCTAssertEqual(prefs.pathTolerance, 18)
        prefs.difficultyLevel = .hard
        XCTAssertEqual(prefs.pathTolerance, 12)
        prefs.difficultyLevel = .easy
        XCTAssertEqual(prefs.pathTolerance, 25)
    }

    // MARK: - Remaining properties still work

    func testTTSEnabledPersists() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.ttsEnabled = false
        XCTAssertFalse(defaults.bool(forKey: "ttsEnabled"))
        prefs.ttsEnabled = true
        XCTAssertTrue(defaults.bool(forKey: "ttsEnabled"))
    }

    func testHasCompletedOnboardingPersists() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.hasCompletedOnboarding = true
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
    }
}

final class AdditionalLanguageLocalizationTests: IsolatedPreferencesTestCase {
    func testRegionalLanguageDetection() {
        XCTAssertEqual(AppLanguage.fromPreferredLanguages(["ko-KR", "en-US"]), .korean)
        XCTAssertEqual(AppLanguage.fromPreferredLanguages(["ar-SA", "en-US"]), .arabic)
        XCTAssertEqual(AppLanguage.fromPreferredLanguages(["ar_EG"]), .arabic)
        XCTAssertEqual(AppLanguage.fromPreferredLanguages(["fr-FR", "ko-KR"]), .korean)
        XCTAssertTrue(AppLanguage.arabic.isRightToLeft)
        XCTAssertFalse(AppLanguage.korean.isRightToLeft)
        XCTAssertEqual(AppLanguage.korean.displayName, "한국어")
        XCTAssertEqual(AppLanguage.arabic.displayName, "العربية")
        for (regionalCode, language) in [("sv-SE", AppLanguage.swedish), ("sv_FI", .swedish),
                                          ("fi-FI", .finnish), ("nl-NL", .dutch), ("nl-BE", .dutch)] {
            XCTAssertEqual(AppLanguage.fromPreferredLanguages([regionalCode, "en-US"]), language)
            XCTAssertFalse(language.isRightToLeft)
            XCTAssertEqual(language.audioPackID, "audio-\(language.rawValue)")
        }
        XCTAssertEqual(AppLanguage.swedish.displayName, "Svenska")
        XCTAssertEqual(AppLanguage.finnish.displayName, "Suomi")
        XCTAssertEqual(AppLanguage.dutch.displayName, "Nederlands")
        XCTAssertEqual(AppLanguage.swedish.speechLanguageIdentifier, "sv-SE")
        XCTAssertEqual(AppLanguage.finnish.speechLanguageIdentifier, "fi-FI")
        XCTAssertEqual(AppLanguage.dutch.speechLanguageIdentifier, "nl-NL")
    }

    func testSelectedLanguagePreservesSavedOnboardingAndProgress() {
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(true, forKey: "appLanguageWasSelectedByUser")
        defaults.set("ar", forKey: "appLanguage")
        let tracker = ProgressTracker(defaults: defaults)
        tracker.markCompleted("denny_067_easy")
        let preferences = UserPreferences(defaults: defaults)
        XCTAssertEqual(preferences.appLanguage, .arabic)
        XCTAssertTrue(preferences.hasCompletedOnboarding)
        preferences.appLanguage = .korean
        let restored = UserPreferences(defaults: defaults)
        XCTAssertEqual(restored.appLanguage, .korean)
        XCTAssertTrue(restored.hasCompletedOnboarding)
        XCTAssertTrue(ProgressTracker(defaults: defaults).completedIds.contains("denny_067_easy"))
        for language in [AppLanguage.swedish, .finnish, .dutch] {
            preferences.appLanguage = language
            let reloaded = UserPreferences(defaults: defaults)
            XCTAssertEqual(reloaded.appLanguage, language)
            XCTAssertTrue(reloaded.hasCompletedOnboarding)
            XCTAssertTrue(ProgressTracker(defaults: defaults).completedIds.contains("denny_067_easy"))
        }
    }

    func testAllActiveLevelsAreTranslatedWithoutChangingMazeData() throws {
        let loader = LabyrinthLoader.shared
        loader.setLanguage(.english)
        let english = Dictionary(uniqueKeysWithValues: loader.loadAll().map { ($0.id, $0) })
        defer { loader.setLanguage(.english) }
        for language in [AppLanguage.korean, .arabic, .swedish, .finnish, .dutch] {
            loader.setLanguage(language)
            let levels = loader.loadAll()
            XCTAssertEqual(Set(levels.map(\.id)), Set(english.keys))
            XCTAssertEqual(Set(levels.map(\.storyNumber)).count, 67)
            for level in levels {
                let original = try XCTUnwrap(english[level.id])
                XCTAssertNotEqual(level.title, original.title, level.id)
                XCTAssertNotEqual(level.storySetup, original.storySetup, level.id)
                XCTAssertNotEqual(level.instruction, original.instruction, level.id)
                XCTAssertNotEqual(level.ttsInstruction, original.ttsInstruction, level.id)
                XCTAssertNotEqual(level.educationalQuestion, original.educationalQuestion, level.id)
                XCTAssertNotEqual(level.funFact, original.funFact, level.id)
                XCTAssertNotEqual(level.completionMessage, original.completionMessage, level.id)
                XCTAssertFalse(level.location?.contains("_") ?? false, level.id)
                XCTAssertEqual(level.itemRule, original.itemRule)
                XCTAssertEqual(level.pathData.solutionPath, original.pathData.solutionPath)
                XCTAssertEqual(level.pathData.startPoint.x, original.pathData.startPoint.x)
                XCTAssertEqual(level.pathData.endPoint.x, original.pathData.endPoint.x)
                XCTAssertEqual(level.pathData.items?.count, original.pathData.items?.count)
                XCTAssertEqual(level.pathData.avoidItems?.count, original.pathData.avoidItems?.count)
            }
        }
    }

    func testCurrentUIAndThanksgivingTitlesAreBundled() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "ui-localizations", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let copy = try JSONDecoder().decode([String: [String: String]].self, from: data)
        for locale in ["ko", "ar", "sv", "fi", "nl"] {
            let localized = try XCTUnwrap(copy[locale])
            for source in ["Your Adventures", "Trace Letters", "Trace Numbers", "Denny's Thanksgiving", "Choose your language"] {
                let value = try XCTUnwrap(localized[source])
                XCTAssertNotEqual(value, source)
                XCTAssertFalse(value.isEmpty)
            }
        }
    }
}
