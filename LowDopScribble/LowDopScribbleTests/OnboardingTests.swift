import XCTest
@testable import LowDopScribble

final class OnboardingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let keys = ["hasCompletedOnboarding", "ttsEnabled", "ttsDefaultSet"]
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }
    }

    override func tearDown() {
        super.tearDown()
        let keys = ["hasCompletedOnboarding", "ttsEnabled", "ttsDefaultSet"]
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }
    }

    // MARK: - hasCompletedOnboarding persistence

    func testCompletingOnboardingSetsUserDefaultsKey() {
        let prefs = UserPreferences()
        XCTAssertFalse(prefs.hasCompletedOnboarding)
        prefs.hasCompletedOnboarding = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }

    func testHasCompletedOnboardingDefaultsToFalse() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        let prefs = UserPreferences()
        XCTAssertFalse(prefs.hasCompletedOnboarding)
    }

    func testHasCompletedOnboardingPersistsAcrossInstances() {
        let prefs1 = UserPreferences()
        prefs1.hasCompletedOnboarding = true
        let prefs2 = UserPreferences()
        XCTAssertTrue(prefs2.hasCompletedOnboarding)
    }

    // MARK: - OnboardingViewModel page navigation

    func testOnboardingStartsOnFirstPage() {
        let vm = OnboardingViewModel()
        XCTAssertEqual(vm.currentPage, 0)
    }

    func testOnboardingTotalPageCount() {
        XCTAssertEqual(OnboardingViewModel.totalPages, 3)
    }

    func testOnboardingPageAdvances() {
        let vm = OnboardingViewModel()
        XCTAssertEqual(vm.attemptAdvance(), .changed)
        XCTAssertEqual(vm.currentPage, 1)
        XCTAssertEqual(vm.attemptAdvance(), .changed)
        XCTAssertEqual(vm.currentPage, 2)
    }

    func testOnboardingPageDoesNotExceedLastPage() {
        let vm = OnboardingViewModel()
        for _ in 0..<10 { _ = vm.attemptAdvance() }
        XCTAssertEqual(vm.currentPage, OnboardingViewModel.totalPages - 1)
    }

    func testIsOnLastPageFlag() {
        let vm = OnboardingViewModel()
        XCTAssertFalse(vm.isOnLastPage)
        vm.currentPage = OnboardingViewModel.totalPages - 1
        XCTAssertTrue(vm.isOnLastPage)
    }

    func testAttemptNavigateToSamePageReturnsUnchanged() {
        let vm = OnboardingViewModel()
        XCTAssertEqual(vm.attemptNavigate(to: 0), .unchanged)
    }

    func testAttemptNavigateForwardReturnsChanged() {
        let vm = OnboardingViewModel()
        XCTAssertEqual(vm.attemptNavigate(to: 1), .changed)
        XCTAssertEqual(vm.currentPage, 1)
    }

    func testAttemptNavigateBackward() {
        let vm = OnboardingViewModel()
        vm.currentPage = 2
        XCTAssertEqual(vm.attemptNavigate(to: 1), .changed)
        XCTAssertEqual(vm.currentPage, 1)
    }
}
