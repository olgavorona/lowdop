import XCTest
@testable import LowDopamineLabyrinth

final class OnboardingAnalyticsTests: XCTestCase {
    private var events: [(name: String, parameters: [String: String])] = []
    private var tracker: OnboardingAnalyticsTracker!

    override func setUp() {
        super.setUp()
        events = []
        tracker = OnboardingAnalyticsTracker { [weak self] name, parameters in
            self?.events.append((name, parameters))
        }
    }

    private func show(_ page: Int) {
        tracker.screenShown(page: page, language: .english, difficulty: .medium)
    }

    private func forward(_ page: Int, method: OnboardingAnalyticsTracker.Method = .button) {
        tracker.transitioned(from: page, to: page + 1, method: method, language: .english, difficulty: .medium)
    }

    private func named(_ name: String) -> [[String: String]] {
        events.filter { $0.name == name }.map(\.parameters)
    }

    func testEveryScreenHasAnEventAndRepeatedAppearancesDoNotInflateViews() {
        for page in 0..<OnboardingViewModel.totalPages {
            show(page)
            show(page)
        }
        XCTAssertEqual(events.map(\.name), ["Onboarding.languageShown", "Onboarding.tutorialShown",
            "Onboarding.labyrinthsShown", "Onboarding.calmShown", "Onboarding.difficultyShown", "Onboarding.paywallShown"])
        XCTAssertEqual(events.map { $0.parameters["step"] }, ["1", "2", "3", "4", "5", "6"])
        XCTAssertTrue(events.allSatisfy { $0.parameters["onboarding_analytics_version"] == "2" })
    }

    func testDefaultEnglishIsConfirmedOnBothContinueAndSwipe() {
        for method in [OnboardingAnalyticsTracker.Method.button, .swipe] {
            events = []
            tracker = OnboardingAnalyticsTracker { [weak self] in self?.events.append(($0, $1)) }
            show(0)
            XCTAssertTrue(named("Language.selected").isEmpty)
            forward(0, method: method)
            XCTAssertEqual(named("Language.selected").count, 1)
            XCTAssertEqual(named("Language.selected").first?["language"], "en")
            XCTAssertEqual(named("Language.selected").first?["selection"], "unchanged")
            XCTAssertEqual(named("Language.selected").first?["method"], method.rawValue)
        }
    }

    func testEnglishDeviceSkipRecordsAutomaticLanguageOnceWithoutAPickerViewOrTransition() {
        tracker.languagePickerSkipped(language: .english, difficulty: .medium)
        show(1)
        tracker.languagePickerSkipped(language: .english, difficulty: .medium)
        show(1)

        XCTAssertEqual(events.map(\.name), [
            "Onboarding.languageSkipped", "Language.selected", "Onboarding.tutorialShown"
        ])
        XCTAssertEqual(named("Onboarding.languageSkipped").first?["reason"], "device_english")
        let selection = named("Language.selected").first
        XCTAssertEqual(selection?["language"], "en")
        XCTAssertEqual(selection?["app_locale"], "en")
        XCTAssertEqual(selection?["source"], "onboarding")
        XCTAssertEqual(selection?["selection"], "automatic")
        XCTAssertEqual(selection?["method"], "device_language")

        forward(1, method: .tutorialSkipped)
        show(2)
        XCTAssertEqual(named("Language.selected").count, 1)
        XCTAssertEqual(named("Onboarding.screenContinued").first?["screen"], "tutorial")
    }

    func testMenuChangesAreSeparateFromTheAcceptedLanguage() {
        show(0)
        tracker.languageChanged(to: .dutch, difficulty: .medium)
        tracker.languageChanged(to: .finnish, difficulty: .medium)
        XCTAssertEqual(named("Language.changed").count, 2)
        XCTAssertTrue(named("Language.selected").isEmpty)
        tracker.transitioned(from: 0, to: 1, method: .swipe, language: .finnish, difficulty: .medium)
        XCTAssertEqual(named("Language.selected").count, 1)
        XCTAssertEqual(named("Language.selected").first?["language"], "fi")
        XCTAssertEqual(named("Language.selected").first?["selection"], "explicit")
        XCTAssertEqual(named("Language.selected").first?["source"], "onboarding")
    }

    func testTutorialSkipButtonAndSwipeProduceTheSameOutcomeEvent() {
        for method in [OnboardingAnalyticsTracker.Method.tutorialSkipped, .swipe] {
            events = []
            tracker = OnboardingAnalyticsTracker { [weak self] in self?.events.append(($0, $1)) }
            show(1)
            forward(1, method: method)
            XCTAssertEqual(named("Onboarding.tutorialSkipped").count, 1)
            XCTAssertEqual(named("Onboarding.screenContinued").count, 1)
            XCTAssertTrue(named("Onboarding.tutorialCompleted").isEmpty)
        }
    }

    func testDrawingCompletionThenAutomaticAdvanceDoesNotDoubleCountCompletion() {
        show(1)
        tracker.tutorialOutcome(completed: true, method: .tutorialCompleted, language: .english, difficulty: .medium)
        forward(1, method: .tutorialCompleted)
        XCTAssertEqual(named("Onboarding.tutorialCompleted").count, 1)
        XCTAssertTrue(named("Onboarding.tutorialSkipped").isEmpty)
    }

    func testSwipeImmediatelyAfterDrawingCompletionIsNotAlsoReportedAsSkipped() {
        show(1)
        tracker.tutorialOutcome(completed: true, method: .tutorialCompleted, language: .english, difficulty: .medium)
        forward(1, method: .swipe)
        XCTAssertEqual(named("Onboarding.tutorialCompleted").count, 1)
        XCTAssertTrue(named("Onboarding.tutorialSkipped").isEmpty)
    }

    func testDefaultDifficultyIsRecordedBeforeTheGateAndNotAgainOnRetriesOrSuccess() {
        for method in [OnboardingAnalyticsTracker.Method.button, .swipe] {
            events = []
            tracker = OnboardingAnalyticsTracker { [weak self] in self?.events.append(($0, $1)) }
            show(4)
            let model = OnboardingViewModel()
            model.currentPage = 4
            XCTAssertEqual(model.attemptNavigate(to: 5), .blockedByParentalGate)
            tracker.forwardAttempt(from: 4, to: 5, method: method, language: .english, difficulty: .medium)
            tracker.parentalGateShown(method: method, language: .english, difficulty: .medium)
            tracker.parentalGateFinished(passed: false, method: method, language: .english, difficulty: .medium)
            XCTAssertTrue(named("Onboarding.paywallShown").isEmpty)
            XCTAssertTrue(named("Onboarding.screenContinued").isEmpty)
            tracker.forwardAttempt(from: 4, to: 5, method: method, language: .english, difficulty: .medium)
            tracker.parentalGateShown(method: method, language: .english, difficulty: .medium)
            tracker.parentalGateFinished(passed: true, method: method, language: .english, difficulty: .medium)
            tracker.transitioned(from: 4, to: 5, method: method, language: .english, difficulty: .medium)
            model.completeParentalGateNavigation(to: 5)
            show(model.currentPage)
            XCTAssertEqual(named("Onboarding.difficultySelected").count, 1)
            XCTAssertEqual(named("Onboarding.difficultySelected").first?["level"], "medium")
            XCTAssertEqual(named("Onboarding.difficultySelected").first?["selection"], "unchanged")
            XCTAssertEqual(named("Onboarding.parentalGateShown").count, 2)
            XCTAssertEqual(named("Onboarding.parentalGateCancelled").count, 1)
            XCTAssertEqual(named("Onboarding.parentalGatePassed").count, 1)
            XCTAssertEqual(named("Onboarding.paywallShown").count, 1)
        }
    }

    func testExplicitDifficultyCanChangeAfterCancelingTheGate() {
        show(4)
        tracker.forwardAttempt(from: 4, to: 5, method: .button, language: .english, difficulty: .medium)
        tracker.difficultyChanged(to: .hard, language: .english)
        tracker.forwardAttempt(from: 4, to: 5, method: .difficultyCard, language: .english, difficulty: .hard)
        XCTAssertEqual(named("Onboarding.difficultySelected").map { $0["level"] }, ["medium", "hard"])
        XCTAssertEqual(named("Onboarding.difficultySelected").last?["selection"], "explicit")
    }

    func testBackwardNavigationOnlyRecordsTheNewScreenVisit() {
        show(1)
        tracker.transitioned(from: 1, to: 0, method: .swipe, language: .english, difficulty: .medium)
        show(0)
        XCTAssertTrue(named("Onboarding.screenContinued").isEmpty)
        XCTAssertTrue(named("Onboarding.tutorialSkipped").isEmpty)
        XCTAssertTrue(named("Language.selected").isEmpty)
        forward(0)
        show(1)
        XCTAssertEqual(named("Onboarding.tutorialShown").count, 2)
    }

    func testNoOpAndInvalidPagesProduceNoEvents() {
        tracker.screenShown(page: -1, language: .english, difficulty: .medium)
        tracker.screenShown(page: 6, language: .english, difficulty: .medium)
        tracker.transitioned(from: 0, to: 0, method: .swipe, language: .english, difficulty: .medium)
        tracker.transitioned(from: 5, to: 6, method: .button, language: .english, difficulty: .medium)
        XCTAssertTrue(events.isEmpty)
    }

    func testCompletionIsSentOnceWithLanguageAndDifficultyContext() {
        tracker.completed(language: .swedish, difficulty: .easy)
        tracker.completed(language: .swedish, difficulty: .easy)
        XCTAssertEqual(named("Onboarding.completed").count, 1)
        XCTAssertEqual(named("Onboarding.completed").first?["app_locale"], "sv")
        XCTAssertEqual(named("Onboarding.completed").first?["difficulty"], "easy")
    }

    func testBothExperimentFunnelsTagEveryEventAndNeverShowTheOmittedScreen() {
        for variant in OnboardingExperimentVariant.allCases {
            events = []
            tracker = OnboardingAnalyticsTracker(variant: variant) { [weak self] in self?.events.append(($0, $1)) }
            let model = OnboardingViewModel(preferredLanguages: ["en-US"], variant: variant)
            tracker.experimentExposed(page: model.currentPage, language: .english, difficulty: .medium)
            tracker.experimentExposed(page: model.currentPage, language: .english, difficulty: .medium)
            tracker.languagePickerSkipped(language: .english, difficulty: .medium)
            show(model.currentPage)
            while !model.isOnLastPage {
                let previousPage = model.currentPage
                if model.attemptAdvance() == .blockedByParentalGate {
                    model.completeParentalGateAdvance()
                }
                tracker.transitioned(from: previousPage, to: model.currentPage, method: .button,
                                     language: .english, difficulty: .medium)
                show(model.currentPage)
            }
            tracker.completed(language: .english, difficulty: .medium)
            XCTAssertEqual(named("Onboarding.experimentExposed").count, 1)
            XCTAssertEqual(named("Onboarding.completed").count, 1)
            XCTAssertTrue(named(variant == .a ? "Onboarding.labyrinthsShown" : "Onboarding.calmShown").isEmpty)
            XCTAssertEqual(named("Onboarding.screenContinued").count, 3)
            XCTAssertTrue(events.allSatisfy { $0.parameters["experiment_id"] == OnboardingExperiment.id })
            XCTAssertTrue(events.allSatisfy { $0.parameters["experiment_variant"] == variant.rawValue })
            XCTAssertTrue(events.allSatisfy { $0.parameters["omitted_screen"] == variant.omittedScreen })
        }
    }
}

final class OnboardingExperimentTests: IsolatedPreferencesTestCase {
    func testAssignmentIsSavedAndNeverRerolledAfterRestart() {
        for variant in OnboardingExperimentVariant.allCases {
            defaults.removeObject(forKey: OnboardingExperiment.assignmentKey)
            XCTAssertEqual(OnboardingExperiment.assignedVariant(defaults: defaults, arguments: [], randomVariant: { variant }), variant)
            XCTAssertEqual(defaults.string(forKey: OnboardingExperiment.assignmentKey), variant.rawValue)
            let saved = OnboardingExperiment.assignedVariant(defaults: defaults, arguments: [], randomVariant: {
                XCTFail("Existing assignments must not be rerolled")
                return variant == .a ? .b : .a
            })
            XCTAssertEqual(saved, variant)
            XCTAssertEqual(OnboardingExperiment.analyticsParameters(defaults: defaults, arguments: []), variant.analyticsParameters)
        }
    }

    func testAnalyticsDoesNotEnrollUsersWhoNeverEnteredOnboarding() {
        XCTAssertTrue(OnboardingExperiment.analyticsParameters(defaults: defaults, arguments: []).isEmpty)
        XCTAssertNil(defaults.object(forKey: OnboardingExperiment.assignmentKey))
    }

    func testInvalidAssignmentIsReplaced() {
        defaults.set("invalid", forKey: OnboardingExperiment.assignmentKey)
        XCTAssertEqual(OnboardingExperiment.assignedVariant(defaults: defaults, arguments: [], randomVariant: { .b }), .b)
        XCTAssertEqual(defaults.string(forKey: OnboardingExperiment.assignmentKey), "B")
    }

    func testQAOverrideDoesNotChangePersistedAssignment() {
        defaults.set("A", forKey: OnboardingExperiment.assignmentKey)
        let arguments = ["-uiTestDisableAnalytics", "-uiTestOnboardingVariant", "B"]
        XCTAssertEqual(OnboardingExperiment.assignedVariant(defaults: defaults, arguments: arguments), .b)
        XCTAssertEqual(OnboardingExperiment.analyticsParameters(defaults: defaults, arguments: arguments)["experiment_variant"], "B")
        XCTAssertEqual(defaults.string(forKey: OnboardingExperiment.assignmentKey), "A")
        XCTAssertEqual(OnboardingExperiment.assignedVariant(defaults: defaults, arguments: ["-uiTestOnboardingVariant", "B"]), .a)
    }

    func testBothVariantsNavigateOnlyVisiblePagesAndPreserveTheParentalGate() {
        for variant in OnboardingExperimentVariant.allCases {
            for language in ["en-US", "de-DE"] {
                let model = OnboardingViewModel(preferredLanguages: [language], variant: variant)
                let expected = (language == "en-US" ? [1, 2, 3, 4, 5] : [0, 1, 2, 3, 4, 5])
                    .filter { $0 != variant.omittedPage }
                XCTAssertEqual(model.visiblePages, expected)
                var visited = [model.currentPage]
                while !model.isOnLastPage {
                    if model.attemptAdvance() == .blockedByParentalGate {
                        XCTAssertEqual(model.currentPage, 4)
                        model.completeParentalGateAdvance()
                    }
                    visited.append(model.currentPage)
                }
                XCTAssertEqual(visited, expected)
                for destination in expected.dropLast().reversed() {
                    XCTAssertEqual(model.attemptNavigate(to: destination), .changed)
                    XCTAssertEqual(model.currentPage, destination)
                }
                XCTAssertEqual(model.attemptNavigate(to: -1), .unchanged)
            }
        }
    }

    func testRequestsForOmittedPagesResolveInTheDirectionOfNavigation() {
        for variant in OnboardingExperimentVariant.allCases {
            let model = OnboardingViewModel(preferredLanguages: ["en"], variant: variant)
            model.currentPage = variant.omittedPage - 1
            XCTAssertEqual(model.attemptNavigate(to: variant.omittedPage), .changed)
            XCTAssertEqual(model.currentPage, variant.omittedPage + 1)
            XCTAssertEqual(model.attemptNavigate(to: variant.omittedPage), .changed)
            XCTAssertEqual(model.currentPage, variant.omittedPage - 1)
        }
    }

    func testAllExperimentCopyIsTranslatedInEverySupportedLanguage() throws {
        let messages = Set(OnboardingExperimentVariant.allCases.flatMap(\.paywallMessages))
        for language in AppLanguage.allCases where language != .english {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language.rawValue, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for source in messages {
                let translated = AppLocalization.text(source, language: language)
                XCTAssertFalse(translated.isEmpty, "\(language): \(source)")
                XCTAssertNotEqual(translated, source, "\(language): \(source)")
                XCTAssertEqual(bundle.localizedString(forKey: source, value: nil, table: nil), translated)
            }
        }
    }
}

// MARK: - OnboardingTests
// Tests for onboarding completion logic, difficulty selection, and page navigation.

final class OnboardingTests: IsolatedPreferencesTestCase {

    func testArchivedFallDeepLinkIsIgnored() throws {
        let url = try XCTUnwrap(URL(string: "dennysmazes://fall"))
        XCTAssertNil(AppDeepLink.packID(for: url))
    }

    func testThanksgivingDeepLinkRoutesToThanksgivingAdventures() throws {
        let url = try XCTUnwrap(URL(string: "dennysmazes://thanksgiving"))
        XCTAssertEqual(AppDeepLink.packID(for: url), "thanksgiving_adventures")
    }

    func testUnsupportedDeepLinkIsIgnored() throws {
        let url = try XCTUnwrap(URL(string: "dennysmazes://ocean"))
        XCTAssertNil(AppDeepLink.packID(for: url))
    }

    // MARK: - hasCompletedOnboarding persistence

    func testCompletingOnboardingSetsUserDefaultsKey() {
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertFalse(prefs.hasCompletedOnboarding, "Should start as false on a clean install")

        prefs.hasCompletedOnboarding = true

        XCTAssertTrue(
            defaults.bool(forKey: "hasCompletedOnboarding"),
            "UserDefaults key 'hasCompletedOnboarding' must be true after completion"
        )
    }

    func testHasCompletedOnboardingDefaultsToFalse() {
        // Ensure the key is absent
        defaults.removeObject(forKey: "hasCompletedOnboarding")
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertFalse(prefs.hasCompletedOnboarding, "Default value must be false (first launch)")
    }

    func testHasCompletedOnboardingPersistsAcrossInstances() {
        let prefs1 = UserPreferences(defaults: defaults)
        prefs1.hasCompletedOnboarding = true

        // Simulate re-launch by creating a new instance
        let prefs2 = UserPreferences(defaults: defaults)
        XCTAssertTrue(prefs2.hasCompletedOnboarding, "Completion flag must survive across UserPreferences instances")
    }

    func testExistingOnboardingAndProgressSurviveSeasonalPackLoading() {
        let standardFlagBeforeTest = UserDefaults.standard.object(forKey: "hasCompletedOnboarding") as? Bool
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(["denny_001_easy", "denny_061_medium"], forKey: "completedLabyrinths")
        let preferences = UserPreferences(defaults: defaults)
        let progress = ProgressTracker(defaults: defaults)
        let game = GameViewModel(
            preferences: preferences, subscriptionManager: SubscriptionManager(),
            progressTracker: progress
        )
        game.loadLabyrinths(packId: "thanksgiving_adventures")
        game.reloadForLanguageChange()

        XCTAssertTrue(preferences.hasCompletedOnboarding)
        XCTAssertTrue(UserPreferences(defaults: defaults).hasCompletedOnboarding)
        XCTAssertTrue(ProgressTracker(defaults: defaults).isCompleted("denny_001_easy"))
        XCTAssertTrue(ProgressTracker(defaults: defaults).isCompleted("denny_061_medium"))
        XCTAssertEqual(UserDefaults.standard.object(forKey: "hasCompletedOnboarding") as? Bool, standardFlagBeforeTest)
    }

    func testSettingHasCompletedOnboardingToFalseResetsKey() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.hasCompletedOnboarding = true
        prefs.hasCompletedOnboarding = false
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedOnboarding"))
    }

    // MARK: - Difficulty selection in onboarding

    func testDifficultySelectionUpdatesUserPreferences() {
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.difficultyLevel, .medium)

        prefs.difficultyLevel = .medium
        XCTAssertEqual(prefs.difficultyLevel, .medium)

        prefs.difficultyLevel = .hard
        XCTAssertEqual(prefs.difficultyLevel, .hard)

        prefs.difficultyLevel = .easy
        XCTAssertEqual(prefs.difficultyLevel, .easy)
    }

    func testDifficultySelectionPersistsToUserDefaults() {
        let prefs = UserPreferences(defaults: defaults)

        prefs.difficultyLevel = .hard
        XCTAssertEqual(
            defaults.string(forKey: "difficultyLevel"),
            "hard",
            "Selected difficulty must be written to UserDefaults"
        )

        prefs.difficultyLevel = .medium
        XCTAssertEqual(defaults.string(forKey: "difficultyLevel"), "medium")
    }

    func testDifficultyDefaultsToMediumOnFirstLaunch() {
        defaults.removeObject(forKey: "difficultyLevel")
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.difficultyLevel, .medium, "First launch must default to Medium")
    }

    func testDifficultySelectionPersistsAcrossInstances() {
        for level in DifficultyLevel.allCases {
            let prefs1 = UserPreferences(defaults: defaults)
            prefs1.difficultyLevel = level

            let prefs2 = UserPreferences(defaults: defaults)
            XCTAssertEqual(prefs2.difficultyLevel, level, "Difficulty must persist across UserPreferences instances")
        }
    }

    // MARK: - Page navigation

    func testOnboardingPageIndexAdvancesCorrectly() {
        let viewModel = OnboardingViewModel(preferredLanguages: ["de-DE"])
        XCTAssertEqual(viewModel.currentPage, 0, "Must start on page 0")

        XCTAssertEqual(viewModel.attemptAdvance(), .changed)
        XCTAssertEqual(viewModel.currentPage, 1)

        XCTAssertEqual(viewModel.attemptAdvance(), .changed)
        XCTAssertEqual(viewModel.currentPage, 2)

        XCTAssertEqual(viewModel.attemptAdvance(), .changed)
        XCTAssertEqual(viewModel.currentPage, 3)
    }

    func testOnboardingPageIndexDoesNotExceedLastPage() {
        let viewModel = OnboardingViewModel()
        // Advance past the end
        for _ in 0..<10 {
            if viewModel.currentPage == OnboardingViewModel.parentalGatePage {
                viewModel.completeParentalGateAdvance()
            } else {
                _ = viewModel.attemptAdvance()
            }
        }
        XCTAssertEqual(
            viewModel.currentPage,
            OnboardingViewModel.totalPages - 1,
            "Page index must be clamped to last page"
        )
    }

    func testOnboardingStartsOnFirstPage() {
        let viewModel = OnboardingViewModel(preferredLanguages: ["de-DE"])
        XCTAssertEqual(viewModel.currentPage, 0)
    }

    func testEnglishDeviceStartsAtTutorialWithFivePagesAndCannotReturnToPicker() {
        for language in ["en", "en-US", "en-GB", "en-AU", "en_US", "EN-us"] {
            let viewModel = OnboardingViewModel(preferredLanguages: [language, "de-DE"])
            XCTAssertEqual(viewModel.currentPage, 1, language)
            XCTAssertFalse(viewModel.showsLanguagePicker, language)
            XCTAssertEqual(Array(viewModel.visiblePages), [1, 2, 3, 4, 5], language)
            XCTAssertEqual(viewModel.attemptNavigate(to: 0), .unchanged, language)
            XCTAssertEqual(viewModel.attemptAdvance(), .changed, language)
            XCTAssertEqual(viewModel.currentPage, 2, language)
            XCTAssertEqual(viewModel.attemptNavigate(to: -1), .changed, language)
            XCTAssertEqual(viewModel.currentPage, 1, language)
        }
    }

    func testNonEnglishAndUnknownDevicesKeepPickerEvenWithEnglishFallback() {
        for languages in [["de-DE", "en-US"], ["ja-JP"], ["fr-FR", "en-US"], ["vi-VN"], []] {
            let viewModel = OnboardingViewModel(preferredLanguages: languages)
            XCTAssertEqual(viewModel.currentPage, 0, "\(languages)")
            XCTAssertTrue(viewModel.showsLanguagePicker, "\(languages)")
            XCTAssertEqual(Array(viewModel.visiblePages), [0, 1, 2, 3, 4, 5])
        }
    }

    func testOnboardingTotalPageCount() {
        XCTAssertEqual(OnboardingViewModel.totalPages, 6, "Onboarding must have exactly 6 pages")
    }

    func testOnboardingIsOnLastPageFlag() {
        let viewModel = OnboardingViewModel()
        XCTAssertFalse(viewModel.isOnLastPage)

        viewModel.currentPage = OnboardingViewModel.totalPages - 1
        XCTAssertTrue(viewModel.isOnLastPage)
    }

    func testDifficultyPageRequiresParentalGateBeforeAdvance() {
        let viewModel = OnboardingViewModel()

        viewModel.currentPage = OnboardingViewModel.parentalGatePage
        XCTAssertTrue(
            viewModel.requiresParentalGateBeforeAdvance,
            "Leaving the difficulty page must require the parental gate"
        )

        viewModel.currentPage = OnboardingViewModel.parentalGatePage - 1
        XCTAssertFalse(viewModel.requiresParentalGateBeforeAdvance)
    }

    func testDifficultyPageBlocksAdvanceUntilParentalGateSucceeds() {
        let viewModel = OnboardingViewModel()
        viewModel.currentPage = OnboardingViewModel.parentalGatePage

        XCTAssertEqual(viewModel.attemptAdvance(), .blockedByParentalGate)
        XCTAssertEqual(viewModel.currentPage, OnboardingViewModel.parentalGatePage)

        viewModel.completeParentalGateNavigation(to: OnboardingViewModel.parentalGatePage + 1)
        XCTAssertEqual(viewModel.currentPage, OnboardingViewModel.parentalGatePage + 1)
    }

    func testParentalGateSuccessCanJumpToStoredDestination() {
        let viewModel = OnboardingViewModel()
        viewModel.currentPage = OnboardingViewModel.parentalGatePage

        viewModel.completeParentalGateNavigation(to: OnboardingViewModel.totalPages - 1)

        XCTAssertEqual(viewModel.currentPage, OnboardingViewModel.totalPages - 1)
    }

    func testSwipeForwardFromDifficultyPageIsBlockedByParentalGate() {
        let viewModel = OnboardingViewModel()
        viewModel.currentPage = OnboardingViewModel.parentalGatePage

        XCTAssertEqual(
            viewModel.attemptNavigate(to: OnboardingViewModel.parentalGatePage + 1),
            .blockedByParentalGate
        )
        XCTAssertEqual(viewModel.currentPage, OnboardingViewModel.parentalGatePage)
    }

    func testSwipeBackFromDifficultyPageDoesNotRequireParentalGate() {
        let viewModel = OnboardingViewModel()
        viewModel.currentPage = OnboardingViewModel.parentalGatePage

        XCTAssertEqual(
            viewModel.attemptNavigate(to: OnboardingViewModel.parentalGatePage - 1),
            .changed
        )
        XCTAssertEqual(viewModel.currentPage, OnboardingViewModel.parentalGatePage - 1)
    }
}
