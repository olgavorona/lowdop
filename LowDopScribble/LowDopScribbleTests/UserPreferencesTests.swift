import XCTest
@testable import LowDopScribble

final class UserPreferencesTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        let keys = ["ttsEnabled", "hasCompletedOnboarding", "ttsDefaultSet"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func testTTSEnabledDefaultsToTrue() {
        UserDefaults.standard.removeObject(forKey: "ttsDefaultSet")
        UserDefaults.standard.removeObject(forKey: "ttsEnabled")
        let prefs = UserPreferences()
        XCTAssertTrue(prefs.ttsEnabled, "TTS should default to enabled on first launch")
    }

    func testTTSEnabledPersists() {
        let prefs = UserPreferences()
        prefs.ttsEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "ttsEnabled"))
        prefs.ttsEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "ttsEnabled"))
    }

    func testHasCompletedOnboardingDefaultsToFalse() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        let prefs = UserPreferences()
        XCTAssertFalse(prefs.hasCompletedOnboarding, "Default value must be false on first launch")
    }

    func testHasCompletedOnboardingPersists() {
        let prefs = UserPreferences()
        prefs.hasCompletedOnboarding = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }

    func testHasCompletedOnboardingPersistsAcrossInstances() {
        let prefs1 = UserPreferences()
        prefs1.hasCompletedOnboarding = true

        let prefs2 = UserPreferences()
        XCTAssertTrue(prefs2.hasCompletedOnboarding, "Completion flag must survive across UserPreferences instances")
    }

    func testSettingHasCompletedOnboardingToFalseResetsKey() {
        let prefs = UserPreferences()
        prefs.hasCompletedOnboarding = true
        prefs.hasCompletedOnboarding = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }
}
