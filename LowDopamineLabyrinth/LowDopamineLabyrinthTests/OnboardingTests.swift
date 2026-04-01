import XCTest
@testable import LowDopamineLabyrinth

// MARK: - OnboardingTests
// Tests for onboarding completion logic, difficulty selection, and page navigation.

final class OnboardingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear all relevant UserDefaults keys before each test
        let keys = ["hasCompletedOnboarding", "difficultyLevel", "ttsEnabled", "ttsDefaultSet"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        super.tearDown()
        let keys = ["hasCompletedOnboarding", "difficultyLevel", "ttsEnabled", "ttsDefaultSet"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - hasCompletedOnboarding persistence

    func testCompletingOnboardingSetsUserDefaultsKey() {
        let prefs = UserPreferences()
        XCTAssertFalse(prefs.hasCompletedOnboarding, "Should start as false on a clean install")

        prefs.hasCompletedOnboarding = true

        XCTAssertTrue(
            UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
            "UserDefaults key 'hasCompletedOnboarding' must be true after completion"
        )
    }

    func testHasCompletedOnboardingDefaultsToFalse() {
        // Ensure the key is absent
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        let prefs = UserPreferences()
        XCTAssertFalse(prefs.hasCompletedOnboarding, "Default value must be false (first launch)")
    }

    func testHasCompletedOnboardingPersistsAcrossInstances() {
        let prefs1 = UserPreferences()
        prefs1.hasCompletedOnboarding = true

        // Simulate re-launch by creating a new instance
        let prefs2 = UserPreferences()
        XCTAssertTrue(prefs2.hasCompletedOnboarding, "Completion flag must survive across UserPreferences instances")
    }

    func testSettingHasCompletedOnboardingToFalseResetsKey() {
        let prefs = UserPreferences()
        prefs.hasCompletedOnboarding = true
        prefs.hasCompletedOnboarding = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }

    // MARK: - Difficulty selection in onboarding

    func testDifficultySelectionUpdatesUserPreferences() {
        let prefs = UserPreferences()
        // Default is easy
        XCTAssertEqual(prefs.difficultyLevel, .easy)

        prefs.difficultyLevel = .medium
        XCTAssertEqual(prefs.difficultyLevel, .medium)

        prefs.difficultyLevel = .hard
        XCTAssertEqual(prefs.difficultyLevel, .hard)

        prefs.difficultyLevel = .easy
        XCTAssertEqual(prefs.difficultyLevel, .easy)
    }

    func testDifficultySelectionPersistsToUserDefaults() {
        let prefs = UserPreferences()

        prefs.difficultyLevel = .hard
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "difficultyLevel"),
            "hard",
            "Selected difficulty must be written to UserDefaults"
        )

        prefs.difficultyLevel = .medium
        XCTAssertEqual(UserDefaults.standard.string(forKey: "difficultyLevel"), "medium")
    }

    func testDifficultyDefaultsToEasyOnFirstLaunch() {
        UserDefaults.standard.removeObject(forKey: "difficultyLevel")
        let prefs = UserPreferences()
        XCTAssertEqual(prefs.difficultyLevel, .easy, "First launch must default to Easy")
    }

    func testDifficultySelectionPersistsAcrossInstances() {
        let prefs1 = UserPreferences()
        prefs1.difficultyLevel = .hard

        let prefs2 = UserPreferences()
        XCTAssertEqual(prefs2.difficultyLevel, .hard, "Difficulty must persist across UserPreferences instances")
    }

    // MARK: - Page navigation

    func testOnboardingPageIndexAdvancesCorrectly() {
        let viewModel = OnboardingViewModel()
        XCTAssertEqual(viewModel.currentPage, 0, "Must start on page 0")

        viewModel.advance()
        XCTAssertEqual(viewModel.currentPage, 1)

        viewModel.advance()
        XCTAssertEqual(viewModel.currentPage, 2)

        viewModel.advance()
        XCTAssertEqual(viewModel.currentPage, 3)
    }

    func testOnboardingPageIndexDoesNotExceedLastPage() {
        let viewModel = OnboardingViewModel()
        // Advance past the end
        for _ in 0..<10 {
            viewModel.advance()
        }
        XCTAssertEqual(
            viewModel.currentPage,
            OnboardingViewModel.totalPages - 1,
            "Page index must be clamped to last page"
        )
    }

    func testOnboardingStartsOnFirstPage() {
        let viewModel = OnboardingViewModel()
        XCTAssertEqual(viewModel.currentPage, 0)
    }

    func testOnboardingTotalPageCount() {
        XCTAssertEqual(OnboardingViewModel.totalPages, 4, "Onboarding must have exactly 4 pages")
    }

    func testOnboardingIsOnLastPageFlag() {
        let viewModel = OnboardingViewModel()
        XCTAssertFalse(viewModel.isOnLastPage)

        viewModel.currentPage = OnboardingViewModel.totalPages - 1
        XCTAssertTrue(viewModel.isOnLastPage)
    }
}
