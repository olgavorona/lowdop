import XCTest
@testable import LowDopamineLabyrinth

final class UserPreferencesTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        let keys = ["difficultyLevel", "ttsEnabled", "hasCompletedOnboarding", "ttsDefaultSet"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

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
        UserDefaults.standard.set("beginner", forKey: "difficultyLevel")
        let prefs = UserPreferences()
        XCTAssertEqual(prefs.difficultyLevel, .easy, "Unknown rawValue 'beginner' should fall back to .easy")
    }

    func testFallbackForExpertDifficultyRawValue() {
        UserDefaults.standard.set("expert", forKey: "difficultyLevel")
        let prefs = UserPreferences()
        XCTAssertEqual(prefs.difficultyLevel, .easy, "Unknown rawValue 'expert' should fall back to .easy")
    }

    func testValidDifficultyRawValueLoadsCorrectly() {
        UserDefaults.standard.set("hard", forKey: "difficultyLevel")
        let prefs = UserPreferences()
        XCTAssertEqual(prefs.difficultyLevel, .hard, "Valid rawValue 'hard' should load correctly")
    }

    // MARK: - pathTolerance on UserPreferences

    func testPathToleranceDelegatesToDifficultyLevel() {
        let prefs = UserPreferences()
        prefs.difficultyLevel = .medium
        XCTAssertEqual(prefs.pathTolerance, 18)
        prefs.difficultyLevel = .hard
        XCTAssertEqual(prefs.pathTolerance, 12)
        prefs.difficultyLevel = .easy
        XCTAssertEqual(prefs.pathTolerance, 25)
    }

    // MARK: - Remaining properties still work

    func testTTSEnabledPersists() {
        let prefs = UserPreferences()
        prefs.ttsEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "ttsEnabled"))
        prefs.ttsEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "ttsEnabled"))
    }

    func testHasCompletedOnboardingPersists() {
        let prefs = UserPreferences()
        prefs.hasCompletedOnboarding = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }
}
