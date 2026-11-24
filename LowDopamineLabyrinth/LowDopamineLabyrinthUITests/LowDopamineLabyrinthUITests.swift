import XCTest

final class LowDopamineLabyrinthUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLastLevelCompletionReturnsToBookshelf() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestDisableAnalytics",
            "-uiTestSelectedPack", "ocean_adventures",
            "-uiTestShowCompletionForLastLevel"
        ]

        app.launch()

        let completionButton = app.buttons["completion.primaryButton"]
        XCTAssertTrue(completionButton.waitForExistence(timeout: 10))
        XCTAssertEqual(completionButton.label, "Back to Bookshelf")

        completionButton.tap()

        let bookshelfTitle = app.staticTexts["bookshelf.title"]
        XCTAssertTrue(bookshelfTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(bookshelfTitle.label, "Your Adventures")
        XCTAssertFalse(app.staticTexts["grid.title"].exists)
    }
}

/// Run on a dedicated simulator: launch arguments override preferences only in that app.
final class TracingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testBookshelfAvailabilityForEveryLanguage() {
        for language in ["en", "de", "es", "ja", "zh-Hans", "ko", "ar", "sv", "fi", "nl"] {
            let app = launch(language: language)
            XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
            // Allow for tracing cards being below the visible area on short screens.
            if !app.buttons["bookshelf.pack.number_tracing"].exists {
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(app.buttons["bookshelf.pack.number_tracing"].exists, language)
            XCTAssertEqual(app.buttons["bookshelf.pack.hiragana_tracing"].exists, language == "ja", language)
            XCTAssertEqual(app.buttons["bookshelf.pack.arabic_tracing"].exists, language == "ar", language)
            if language == "ja" {
                XCTAssertTrue(app.buttons["bookshelf.pack.hiragana_tracing"].label.contains("あ"))
            }
            if language == "en" || language == "ja" {
                attachScreenshot(app, name: "Bookshelf rows \(language) portrait")
            }
            if language == "ja" {
                XCUIDevice.shared.orientation = .landscapeLeft
                app.scrollViews.firstMatch.swipeUp()
                attachScreenshot(app, name: "Bookshelf rows Japanese landscape")
                XCUIDevice.shared.orientation = .portrait
            }
            app.terminate()
        }
    }

    func testOnboardingAnalyticsWithButtonsAndUnchangedDefaults() {
        let app = launchOnboardingAnalyticsCapture("button")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Choose your language"].waitForExistence(timeout: 10))
        app.buttons["onboarding.languageAction"].tap()
        XCTAssertTrue(app.staticTexts["Draw the Path"].waitForExistence(timeout: 10))
        app.buttons["Skip for Now"].tap()
        XCTAssertTrue(app.staticTexts["Labyrinths to Explore"].waitForExistence(timeout: 10))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Set the Difficulty"].waitForExistence(timeout: 10))
        app.buttons["Next"].tap()
        answerShelfParentalGate(in: app, continueTitle: "Continue")
        XCTAssertTrue(app.staticTexts["Ready to Explore?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No ads"].exists)
        XCTAssertTrue(app.staticTexts["100+ levels work offline"].exists)
        XCTAssertFalse(app.staticTexts["100+ mazes"].exists)
        app.buttons["Start for Free →"].tap()
        XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
    }

    func testOnboardingAnalyticsWithSwipesAndParentalGateRetry() {
        let app = launchOnboardingAnalyticsCapture("swipe")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Choose your language"].waitForExistence(timeout: 10))
        for title in ["Draw the Path", "Labyrinths to Explore", "Set the Difficulty"] {
            swipeOnboardingForward(in: app)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), title)
        }
        swipeOnboardingForward(in: app)
        let cancel = app.buttons["Go Back"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(app.staticTexts["Set the Difficulty"].waitForExistence(timeout: 10))
        swipeOnboardingForward(in: app)
        answerShelfParentalGate(in: app, continueTitle: "Continue")
        XCTAssertTrue(app.staticTexts["Ready to Explore?"].waitForExistence(timeout: 10))
        app.buttons["Start for Free →"].tap()
        XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
    }

    func testEnglishDeviceSkipsLanguagePickerAndCompletesOnboarding() {
        let app = launchOnboardingAnalyticsCapture("english-device", deviceLanguage: "en-GB")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Draw the Path"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding.languagePicker"].exists)
        XCTAssertFalse(app.buttons["onboarding.languageAction"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.16))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.16)))
        XCTAssertTrue(app.staticTexts["Draw the Path"].exists)
        XCTAssertFalse(app.buttons["onboarding.languagePicker"].exists)
        attachScreenshot(app, name: "English device starts at tutorial")
        app.buttons["Skip for Now"].tap()
        for title in ["Labyrinths to Explore", "Set the Difficulty"] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), title)
            app.buttons["Next"].tap()
        }
        answerShelfParentalGate(in: app, continueTitle: "Continue")
        XCTAssertTrue(app.staticTexts["Ready to Explore?"].waitForExistence(timeout: 10))
        app.buttons["Start for Free →"].tap()
        XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
    }

    func testNonEnglishDeviceKeepsPickerWhenAppUsesEnglishFallback() {
        let app = launchOnboardingAnalyticsCapture("non-english-device", deviceLanguage: "fr-FR")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Choose your language"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["onboarding.languagePicker"].exists)
        app.buttons["onboarding.languageAction"].tap()
        XCTAssertTrue(app.staticTexts["Draw the Path"].waitForExistence(timeout: 10))
    }

    func testOnboardingVariantAWithButtonsAndPaywallBenefits() {
        let app = launchOnboardingAnalyticsCapture("variant-a", deviceLanguage: "en-US", variant: "A")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Draw the Path"].waitForExistence(timeout: 10))
        app.buttons["Skip for Now"].tap()
        XCTAssertTrue(app.staticTexts["Calm & Focused"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Labyrinths to Explore"].exists)
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["Draw the Path"].waitForExistence(timeout: 10))
        app.buttons["Skip for Now"].tap()
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Set the Difficulty"].waitForExistence(timeout: 10))
        app.buttons["Next"].tap()
        answerShelfParentalGate(in: app, continueTitle: "Continue")
        XCTAssertTrue(app.staticTexts["Ready to Explore?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["100+ mazes"].exists)
        XCTAssertTrue(app.staticTexts["Seasonal content every month"].exists)
        XCTAssertFalse(app.staticTexts["100+ levels work offline"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Forever access").count, 2)
        assertPaywallButtonsFit(in: app, secondaryTitle: "Start for Free →")
        attachScreenshot(app, name: "Variant A paywall English")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["paywall.purchase"].isHittable)
        XCTAssertTrue(app.buttons["Start for Free →"].isHittable)
        assertPaywallButtonsFit(in: app, secondaryTitle: "Start for Free →")
        attachScreenshot(app, name: "Variant A paywall English landscape")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["Start for Free →"].tap()
        XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
    }

    func testOnboardingVariantBWithButtonsAndPaywallBenefits() {
        let app = launchOnboardingAnalyticsCapture("variant-b", deviceLanguage: "en-US", variant: "B")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Draw the Path"].waitForExistence(timeout: 10))
        app.buttons["Skip for Now"].tap()
        XCTAssertTrue(app.staticTexts["Labyrinths to Explore"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Seasonal content every month"].exists)
        XCTAssertFalse(app.staticTexts["Calm & Focused"].exists)
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Set the Difficulty"].waitForExistence(timeout: 10))
        app.buttons["Next"].tap()
        answerShelfParentalGate(in: app, continueTitle: "Continue")
        XCTAssertTrue(app.staticTexts["Ready to Explore?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No ads"].exists)
        XCTAssertTrue(app.staticTexts["100+ levels work offline"].exists)
        XCTAssertFalse(app.staticTexts["100+ mazes"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Forever access").count, 2)
        assertPaywallButtonsFit(in: app, secondaryTitle: "Start for Free →")
        attachScreenshot(app, name: "Variant B paywall English")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["paywall.purchase"].isHittable)
        XCTAssertTrue(app.buttons["Start for Free →"].isHittable)
        assertPaywallButtonsFit(in: app, secondaryTitle: "Start for Free →")
        attachScreenshot(app, name: "Variant B paywall English landscape")
        XCUIDevice.shared.orientation = .portrait
        let portraitReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width
                && app.buttons["Start for Free →"].isHittable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [portraitReady], timeout: 10), .completed)
        app.buttons["Start for Free →"].tap()
        XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
    }

    func testLocalizedExperimentPaywalls() {
        for (language, variant, skipTitle, nextTitle, continueTitle, heading, firstBenefit, secondBenefit, foreverBenefit, startFree) in [
            ("de", "A", "Vorerst überspringen", "Weiter", "Weiter", "Bereit zum Entdecken?",
             "100+ Labyrinthe", "Jeden Monat saisonale Inhalte", "Dauerhafter Zugriff", "Kostenlos starten →"),
            ("ar", "B", "تخطّي الآن", "التالي", "متابعة", "هل أنت مستعد للاستكشاف؟",
             "بدون إعلانات", "أكثر من 100 مستوى تعمل دون إنترنت", "وصول مدى الحياة", "ابدأ مجانًا →")
        ] {
            let app = launchOnboardingAnalyticsCapture("localized", deviceLanguage: "en-US", variant: variant, appLanguage: language)
            let skip = app.buttons[skipTitle]
            XCTAssertTrue(skip.waitForExistence(timeout: 10))
            skip.tap()
            for _ in 0..<2 {
                let next = app.buttons[nextTitle]
                XCTAssertTrue(next.waitForExistence(timeout: 10))
                next.tap()
            }
            answerShelfParentalGate(in: app, continueTitle: continueTitle)
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts[firstBenefit].isHittable)
            XCTAssertTrue(app.staticTexts[secondBenefit].isHittable)
            XCTAssertTrue(app.staticTexts.matching(identifier: foreverBenefit).firstMatch.isHittable)
            XCTAssertTrue(app.buttons[startFree].isHittable)
            attachScreenshot(app, name: "Variant \(variant) paywall \(language)")
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(app.buttons[startFree].isHittable)
            XCTAssertTrue(app.buttons["paywall.purchase"].isHittable)
            attachScreenshot(app, name: "Variant \(variant) paywall \(language) landscape")
            XCUIDevice.shared.orientation = .portrait
            app.buttons[startFree].tap()
            XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
            app.terminate()
        }
    }

    func testExperimentAssignmentSurvivesAppRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestDisableAnalytics", "-uiTestRecordOnboardingAnalytics",
            "-AppleLanguages", "(en-US)", "-appLanguage", "en",
            "-appLanguageWasSelectedByUser", "YES", "-hasCompletedOnboarding", "NO",
            "-ttsEnabled", "NO", "-ttsDefaultSet", "YES"
        ]
        defer { app.terminate() }
        app.launch()
        XCTAssertTrue(app.buttons["Skip for Now"].waitForExistence(timeout: 10))
        app.buttons["Skip for Now"].tap()
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        let benefitScreen = app.staticTexts["Calm & Focused"].exists ? "Calm & Focused" : "Labyrinths to Explore"
        XCTAssertTrue(app.staticTexts[benefitScreen].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Skip for Now"].waitForExistence(timeout: 10))
        app.buttons["Skip for Now"].tap()
        XCTAssertTrue(app.staticTexts[benefitScreen].waitForExistence(timeout: 10))
    }

    func testOnboardingPaywallScreenshotVariants() {
        for (language, variant, heading, forever) in [
            ("en", "A", "Ready to Explore?", "Forever access"),
            ("en", "B", "Ready to Explore?", "Forever access"),
            ("de", "A", "Bereit zum Entdecken?", "Dauerhafter Zugriff"),
            ("ar", "B", "هل أنت مستعد للاستكشاف؟", "وصول مدى الحياة")
        ] {
            let app = XCUIApplication()
            app.launchArguments = [
                "-uiTestDisableAnalytics", "-uiTestPreviewOnboardingPaywall", "-uiTestOnboardingVariant", variant,
                "-AppleLanguages", "(en-US)", "-appLanguage", language, "-appLanguageWasSelectedByUser", "YES",
                "-hasCompletedOnboarding", "NO", "-isDiscountEligible", "NO", "-ttsEnabled", "NO", "-ttsDefaultSet", "YES"
            ]
            app.launch()
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["$6.99"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts.matching(identifier: forever).firstMatch.isHittable)
            XCTAssertTrue(app.buttons["paywall.purchase"].isHittable)
            let localeName = language == "en" ? "English" : language
            attachScreenshot(app, name: "Variant \(variant) paywall \(localeName)")
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(app.buttons["paywall.purchase"].isHittable)
            attachScreenshot(app, name: "Variant \(variant) paywall \(localeName) landscape")
            XCUIDevice.shared.orientation = .portrait
            app.terminate()
        }
    }

    func testRegularPaywallLayoutAndDismissal() {
        let app = launch(language: "en", captureAnalytics: true, discountEligible: false)
        defer { app.terminate() }
        let account = app.buttons["bookshelf.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        account.tap()
        answerShelfParentalGate(in: app, continueTitle: "Continue")
        let fullAccess = app.buttons["Get Full Access"]
        XCTAssertTrue(fullAccess.waitForExistence(timeout: 10))
        fullAccess.tap()
        let close = app.buttons["paywall.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Unlock all of Denny's Maze"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Forever access").count, 2)
        XCTAssertFalse(app.staticTexts["No ads"].exists)
        XCTAssertFalse(app.staticTexts["No subscription"].exists)
        attachScreenshot(app, name: "Regular lifetime paywall portrait")
        let purchase = app.buttons["paywall.purchase"]
        XCTAssertTrue(purchase.isHittable)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(purchase.waitForExistence(timeout: 10))
        XCTAssertTrue(purchase.isHittable)
        attachScreenshot(app, name: "Regular lifetime paywall landscape")
        close.tap()
        XCTAssertTrue(fullAccess.waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .portrait
    }

    func testDiscountPaywallLayoutAndDismissal() {
        let app = launch(language: "en", captureAnalytics: true, discountEligible: true)
        defer { app.terminate() }
        let account = app.buttons["bookshelf.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        account.tap()
        answerShelfParentalGate(in: app, continueTitle: "Continue")
        let fullAccess = app.buttons["Get Full Access"]
        XCTAssertTrue(fullAccess.waitForExistence(timeout: 10))
        fullAccess.tap()
        let close = app.buttons["paywall.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Keep exploring with Denny"].exists)
        XCTAssertTrue(app.staticTexts["Special unlock price"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Unlock all mazes"].exists)
        XCTAssertTrue(app.staticTexts["Works offline"].exists)
        XCTAssertTrue(app.staticTexts["Forever access"].exists)
        XCTAssertFalse(app.staticTexts["All difficulty levels"].exists)
        XCTAssertFalse(app.staticTexts["No ads"].exists)
        XCTAssertFalse(app.staticTexts["No subscription"].exists)
        XCTAssertTrue(app.buttons["paywall.purchase"].isHittable)
        attachScreenshot(app, name: "Discount lifetime paywall portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["paywall.purchase"].isHittable)
        attachScreenshot(app, name: "Discount lifetime paywall landscape")
        close.tap()
        XCTAssertTrue(fullAccess.waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .portrait
    }

    private func launchOnboardingAnalyticsCapture(_ name: String, deviceLanguage: String = "de-DE", variant: String = "B", appLanguage: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestDisableAnalytics", "-uiTestRecordOnboardingAnalytics",
            "-uiTestOnboardingVariant", variant,
            "-AppleLanguages", "(\(deviceLanguage))",
            "-hasCompletedOnboarding", "NO", "-appLanguage", appLanguage,
            "-appLanguageWasSelectedByUser", "YES", "-difficultyLevel", "medium",
            "-ttsEnabled", "NO", "-ttsDefaultSet", "YES"
        ]
        app.launchEnvironment["ONBOARDING_ANALYTICS_CAPTURE"] = name
        app.launch()
        return app
    }

    private func swipeOnboardingForward(in app: XCUIApplication) {
        // Stay above the drawing canvas so the gesture navigates the page.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.16))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.16)))
    }

    private func assertPaywallButtonsFit(in app: XCUIApplication, secondaryTitle: String,
                                         file: StaticString = #filePath, line: UInt = #line) {
        let bounds = app.windows.firstMatch.frame
        for button in [app.buttons["paywall.purchase"], app.buttons[secondaryTitle]] {
            XCTAssertTrue(button.isHittable, file: file, line: line)
            XCTAssertTrue(bounds.insetBy(dx: -1, dy: -1).contains(button.frame), file: file, line: line)
            if min(bounds.width, bounds.height) >= 600 {
                XCTAssertLessThan(button.frame.width, bounds.width * 0.8,
                                  "Tablet actions should sit within a readable card rather than span the display",
                                  file: file, line: line)
            }
        }
    }

    func testOnboardingLanguageActionUpdatesImmediatelyAfterSelection() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestDisableAnalytics", "-hasCompletedOnboarding", "NO",
            "-AppleLanguages", "(de-DE)",
            "-appLanguage", "en", "-appLanguageWasSelectedByUser", "YES",
            "-ttsEnabled", "NO", "-ttsDefaultSet", "YES"
        ]
        app.launch()
        defer { app.terminate() }
        let action = app.buttons["onboarding.languageAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        XCTAssertEqual(action.label, "Continue")
        for (language, title, heading) in [
            ("Nederlands", "Doorgaan", "Kies je taal"),
            ("Svenska", "Fortsätt", "Välj ditt språk"),
            ("Suomi", "Jatka", "Valitse kielesi"),
            ("English", "Continue", "Choose your language")
        ] {
            selectShelfLanguage(language, pickerID: "onboarding.languagePicker", in: app)
            let translated = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", title), object: action
            )
            XCTAssertEqual(XCTWaiter.wait(for: [translated], timeout: 5), .completed, language)
            XCTAssertTrue(app.staticTexts[heading].exists, language)
            attachScreenshot(app, name: "Onboarding language changed immediately to \(language)")
        }
    }

    func testAdditionalLanguageBookshelfTranslations() {
        for (language, title) in [("ko", "나의 모험"), ("ar", "مغامراتك"),
                                  ("sv", "Dina äventyr"), ("fi", "Omat seikkailut"), ("nl", "Jouw avonturen")] {
            let app = launch(language: language)
            let bookshelfTitle = app.staticTexts["bookshelf.title"]
            XCTAssertTrue(bookshelfTitle.waitForExistence(timeout: 10))
            XCTAssertEqual(bookshelfTitle.label, title)
            XCTAssertTrue(app.buttons["bookshelf.pack.number_tracing"].exists)
            XCTAssertTrue(app.buttons["bookshelf.pack.letter_tracing"].exists)
            XCTAssertFalse(app.buttons["bookshelf.pack.hiragana_tracing"].exists)
            attachScreenshot(app, name: "Bookshelf \(language)")
            app.terminate()
        }
    }

    func testArabicKeepsNumberOrderAndTracingControls() {
        let app = launch(language: "ar", pack: "number_tracing")
        let zero = app.buttons["tracing.glyph.0"]
        let one = app.buttons["tracing.glyph.1"]
        XCTAssertTrue(zero.waitForExistence(timeout: 10))
        XCTAssertLessThan(zero.frame.midX, one.frame.midX)
        zero.tap()
        let example = element("tracing.example", in: app)
        XCTAssertTrue(example.waitForExistence(timeout: 10))
        XCTAssertEqual(example.label, "0")
        let previous = app.buttons["tracing.previous"]
        let next = app.buttons["tracing.next"]
        XCTAssertLessThan(previous.frame.midX, next.frame.midX)
        XCTAssertFalse(previous.isEnabled)
        next.tap()
        XCTAssertEqual(example.label, "1")
        attachScreenshot(app, name: "Arabic number tracing retains drawing orientation")
        app.buttons["tracing.close"].tap()
        XCTAssertTrue(zero.waitForExistence(timeout: 5))
    }

    func testArabicShelfStartsWithFreePacksAfterSettingsChange() {
        let app = prepareEnglishShelfPreference()
        app.launchArguments = shelfLanguageTestArguments + ["-hasCompletedOnboarding", "YES"]
        app.launch()
        let account = app.buttons["bookshelf.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        account.tap()
        answerShelfParentalGate(in: app, continueTitle: "Continue")
        selectShelfLanguage("العربية", pickerID: "account.languagePicker", in: app)
        let done = app.buttons["account.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), app.debugDescription)
        let close = done.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: close.midX, dy: close.midY)).tap()
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.buttons["account.languagePicker"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        verifyArabicShelfBeforeAndAfterRestart(app, source: "Settings")
    }

    func testArabicShelfStartsWithFreePacksAfterOnboarding() {
        let app = prepareEnglishShelfPreference()
        app.launch()
        selectShelfLanguage("العربية", pickerID: "onboarding.languagePicker", in: app)
        app.buttons["متابعة"].tap()
        let skip = app.buttons["تخطّي الآن"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10), app.debugDescription)
        skip.tap()
        for _ in 0..<2 {
            let next = app.buttons["التالي"]
            XCTAssertTrue(next.waitForExistence(timeout: 5), app.debugDescription)
            next.tap()
        }
        answerShelfParentalGate(in: app, continueTitle: "متابعة")
        let startFree = app.buttons["ابدأ مجانًا →"]
        XCTAssertTrue(startFree.waitForExistence(timeout: 10), app.debugDescription)
        startFree.tap()
        verifyArabicShelfBeforeAndAfterRestart(app, source: "Onboarding")
    }

    private var shelfLanguageTestArguments: [String] {
        // Do not override appLanguage: these checks exercise real language changes.
        ["-uiTestDisableAnalytics", "-uiTestOnboardingVariant", "B", "-AppleLanguages", "(de-DE)", "-appLanguageWasSelectedByUser", "YES",
         "-ttsEnabled", "NO", "-ttsDefaultSet", "YES"]
    }

    private func prepareEnglishShelfPreference() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = shelfLanguageTestArguments + ["-hasCompletedOnboarding", "NO"]
        app.launch()
        selectShelfLanguage("English", pickerID: "onboarding.languagePicker", in: app)
        app.terminate()
        return app
    }

    private func selectShelfLanguage(_ name: String, pickerID: String, in app: XCUIApplication) {
        let picker = app.buttons[pickerID]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), app.debugDescription)
        // iOS 27 reports a non-hittable AX point for this menu inside a sheet.
        let icon = picker.images["globe"].frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: icon.midX, dy: icon.midY)).tap()
        let choice = app.buttons[name]
        XCTAssertTrue(choice.waitForExistence(timeout: 5), app.debugDescription)
        choice.tap()
    }

    private func answerShelfParentalGate(in app: XCUIApplication, continueTitle: String) {
        let question = app.staticTexts["parentalGate.question"]
        XCTAssertTrue(question.waitForExistence(timeout: 10), app.debugDescription)
        let numbers = question.label.split(whereSeparator: { !$0.isNumber }).map {
            $0.reduce(0) { $0 * 10 + ($1.wholeNumberValue ?? 0) }
        }
        XCTAssertEqual(numbers.count, 2, question.label)
        guard numbers.count == 2 else { return }
        let answer = app.textFields["parentalGate.answer"]
        answer.tap()
        answer.typeText(String(numbers[0] + numbers[1]))
        let continueButton = app.buttons["parentalGate.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertEqual(answer.value as? String, String(numbers[0] + numbers[1]))
        let bounds = app.windows.firstMatch.frame
        if min(bounds.width, bounds.height) >= 600 {
            // iOS 26's floating number pad obscures XCTest's inferred hit point.
            // Tap the visible right edge of the actual Continue button.
            continueButton.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            // The first tap dismisses the floating keyboard on iOS 26.
            if !question.waitForNonExistence(timeout: 1) {
                let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: continueButton)
                XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
                continueButton.tap()
            }
        } else {
            question.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
            continueButton.tap()
        }
        XCTAssertTrue(question.waitForNonExistence(timeout: 10), "The parental gate must close after the correct answer")
    }

    private func verifyArabicShelfBeforeAndAfterRestart(_ app: XCUIApplication, source: String) {
        let ocean = app.buttons["bookshelf.pack.ocean_adventures"]
        XCTAssertTrue(ocean.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["bookshelf.account"].isHittable)
        let bounds = app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
        let initialOceanVisible = bounds.contains(ocean.frame) && ocean.isHittable
        let thanksgiving = app.buttons["bookshelf.pack.thanksgiving_adventures"]
        let initialThanksgivingVisible = bounds.contains(thanksgiving.frame) && thanksgiving.isHittable
        attachScreenshot(app, name: "Arabic shelf immediately after \(source)")
        app.terminate()
        app.launchArguments = shelfLanguageTestArguments + ["-hasCompletedOnboarding", "YES"]
        app.launch()
        XCTAssertTrue(ocean.waitForExistence(timeout: 10))
        attachScreenshot(app, name: "Arabic shelf after restart from \(source)")
        XCTAssertTrue(bounds.contains(ocean.frame) && ocean.isHittable, "Ocean must be fully visible after restart")
        XCTAssertTrue(initialOceanVisible, "Ocean must be fully visible immediately after \(source)")
        XCTAssertTrue(initialThanksgivingVisible, "Thanksgiving must be fully visible immediately after \(source)")
        app.terminate()
    }

    /// Run with scripts/local_audio_mock_server.py serving the complete generated packs.
    /// This exercises the download gate without accessing App Store Connect.
    func testAdditionalLanguageNarrationDownloadWhenLocalPacksAreAvailable() throws {
        for language in ["ko", "ar", "sv", "fi", "nl"] {
            let url = URL(string: "http://127.0.0.1:8765/\(language)/manifest.json")!
            let filenames: [String]
            do {
                filenames = try JSONDecoder().decode([String].self, from: Data(contentsOf: url))
            } catch {
                throw XCTSkip("Start the local audio mock server to test narration downloads.")
            }
            guard filenames.count == 203 else {
                throw XCTSkip("The complete \(language) narration pack is required for this check.")
            }
        }

        for (language, downloadTitle, continueTitle, tutorialTitle) in [
            ("ko", "한국어 음성 해설 다운로드", "계속", "길을 그려요"),
            ("ar", "تنزيل السرد الصوتي بلغة العربية", "متابعة", "ارسم المسار"),
            ("sv", "Hämta berättarröst: Svenska", "Fortsätt", "Rita vägen"),
            ("fi", "Lataa äänikerronta: Suomi", "Jatka", "Piirrä reitti"),
            ("nl", "Gesproken tekst downloaden: Nederlands", "Doorgaan", "Teken het pad")
        ] {
            let app = XCUIApplication()
            app.launchArguments = [
                "-uiTestDisableAnalytics", "-hasCompletedOnboarding", "NO",
                "-AppleLanguages", "(\(language))",
                "-appLanguage", language, "-appLanguageWasSelectedByUser", "YES",
                "-ttsEnabled", "NO", "-ttsDefaultSet", "YES", "-useLocalAudioMockServer"
            ]
            app.launch()
            let download = app.buttons[downloadTitle]
            // Reuse a saved QA pack when rerunning the test; download fresh packs otherwise.
            if download.waitForExistence(timeout: 3) {
                download.tap()
            }
            let next = app.buttons[continueTitle]
            XCTAssertTrue(next.waitForExistence(timeout: 60), app.debugDescription)
            attachScreenshot(app, name: "Narration downloaded \(language)")
            app.terminate()

            // A new process must discover the saved pack and keep onboarding usable offline.
            app.launch()
            XCTAssertTrue(next.waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertFalse(download.exists)
            next.tap()
            let tutorial = app.staticTexts[tutorialTitle]
            XCTAssertTrue(tutorial.waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertTrue(tutorial.isHittable)
            attachScreenshot(app, name: "Localized tracing tutorial \(language)")
            app.terminate()
        }
    }

    /// Capture on dedicated Arabic screenshot simulators; all settings are launch overrides.
    func testCaptureArabicAppStoreScreenshots() {
        captureArabicScreenshots(rawLayout: false)
    }

    func testCaptureArabicRawScreenshots() {
        captureArabicScreenshots(rawLayout: true)
    }

    private func captureArabicScreenshots(rawLayout: Bool) {
        var app = launch(language: "ar", pack: "arabic_tracing")
        let tha = app.buttons["tracing.glyph.ث"]
        XCTAssertTrue(tha.waitForExistence(timeout: 10))
        let portraitPhone = rawLayout && app.windows.firstMatch.frame.width < 600
        let orientationName = portraitPhone ? "portrait" : "landscape"
        let prefix = rawLayout ? "raw-ar" : "store-ar"
        if rawLayout && !portraitPhone { XCUIDevice.shared.orientation = .landscapeLeft }
        attachScreenshot(app, name: "\(prefix)-07-alphabet-\(rawLayout ? orientationName : "portrait")")
        tha.tap()
        XCTAssertTrue(element("tracing.example", in: app).waitForExistence(timeout: 10))
        if !rawLayout { attachScreenshot(app, name: "store-ar-tracing-portrait") }
        if !portraitPhone { XCUIDevice.shared.orientation = .landscapeLeft }
        attachScreenshot(app, name: "\(prefix)-02-tracing-\(orientationName)")
        app.terminate()

        for (level, name) in [(10, "01-star-maze"), (7, "03-yellow-maze"), (3, "05-ocean-maze")] {
            app = XCUIApplication()
            app.launchArguments = [
                "-uiTestDisableAnalytics", "-hasCompletedOnboarding", "YES",
                "-appLanguage", "ar", "-appLanguageWasSelectedByUser", "YES",
                "-ttsEnabled", "NO", "-ttsDefaultSet", "YES", "-difficultyLevel", "medium",
                "-uiTestSelectedPack", "ocean_adventures", "-uiTestOpenLevel", String(level)
            ]
            app.launch()
            XCTAssertTrue(app.buttons["maze.reset"].waitForExistence(timeout: 10), app.debugDescription)
            attachScreenshot(app, name: "\(prefix)-\(name)-\(orientationName)")
            app.terminate()
        }

        app = XCUIApplication()
        app.launchArguments = [
            "-uiTestDisableAnalytics", "-hasCompletedOnboarding", "NO",
            "-AppleLanguages", "(ar)", "-appLanguage", "ar", "-appLanguageWasSelectedByUser", "YES",
            "-ttsEnabled", "NO", "-ttsDefaultSet", "YES", "-uiTestOnboardingVariant", "B"
        ]
        app.launch()
        let languageAction = app.buttons["onboarding.languageAction"]
        XCTAssertTrue(languageAction.waitForExistence(timeout: 10))
        languageAction.tap()
        XCTAssertTrue(app.staticTexts["ارسم المسار"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "\(prefix)-04-tutorial-\(orientationName)")
        app.buttons["تخطّي الآن"].tap()
        app.buttons["التالي"].tap()
        XCTAssertTrue(app.staticTexts["تحديد الصعوبة"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "\(prefix)-06-difficulty-\(orientationName)")
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    func testArabicLettersReadRightToLeftAndKeepFreeDrawingControls() {
        let app = launch(language: "ar", pack: "arabic_tracing")
        let alif = app.buttons["tracing.glyph.ا"]
        let ba = app.buttons["tracing.glyph.ب"]
        XCTAssertTrue(alif.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(alif.frame.midX, ba.frame.midX)
        attachScreenshot(app, name: "Arabic alphabet grid portrait")
        ba.tap()
        let example = element("tracing.example", in: app)
        XCTAssertTrue(example.waitForExistence(timeout: 10))
        XCTAssertEqual(example.label, "ب")
        let practice = element("tracing.practice", in: app)
        practice.swipeRight()
        app.buttons["tracing.restart"].tap()
        attachScreenshot(app, name: "Arabic ba body and separate dot portrait")
        app.buttons["tracing.next"].tap()
        XCTAssertEqual(example.label, "ت")
        app.buttons["tracing.previous"].tap()
        XCTAssertEqual(example.label, "ب")
        XCUIDevice.shared.orientation = .landscapeLeft
        attachScreenshot(app, name: "Arabic ba stroke order landscape")
        app.buttons["tracing.close"].tap()
        XCTAssertTrue(alif.waitForExistence(timeout: 10))
        app.terminate()
    }

    func testArabicCollectionCannotOpenInOtherLanguages() {
        let app = launch(language: "en", pack: "arabic_tracing")
        XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["tracing.glyph.ا"].exists)
        XCTAssertFalse(app.buttons["bookshelf.pack.arabic_tracing"].exists)
        app.terminate()
    }

    func testNumbersDrawRestartNavigateAndClose() {
        let app = launch(language: "en", pack: "number_tracing")
        let zero = app.buttons["tracing.glyph.0"]
        XCTAssertTrue(zero.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tracing.glyph.9"].exists)
        zero.tap()
        let example = element("tracing.example", in: app)
        XCTAssertTrue(example.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(example.label, "0")
        XCTAssertFalse(app.buttons["tracing.previous"].isEnabled)

        let practice = element("tracing.practice", in: app)
        practice.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: practice.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.7)))
        app.buttons["tracing.restart"].tap()
        app.buttons["tracing.next"].tap()
        XCTAssertEqual(example.label, "1")
        attachScreenshot(app, name: "Number 1 ordered and dotted examples above gray guides")
        app.buttons["tracing.previous"].tap()
        XCTAssertEqual(example.label, "0")
        attachScreenshot(app, name: "Number tracing")
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["tracing.restart"].tap()
        attachScreenshot(app, name: "More number copies in landscape")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["tracing.restart"].tap()
        app.buttons["tracing.close"].tap()
        XCTAssertTrue(zero.waitForExistence(timeout: 5))
    }

    func testHiraganaPathsAndLastCharacterAreReachable() {
        let app = launch(language: "ja", pack: "hiragana_tracing")
        let first = app.buttons["tracing.glyph.あ"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        let example = element("tracing.example", in: app)
        XCTAssertTrue(example.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(example.label, "あ")
        attachScreenshot(app, name: "Hiragana あ stroke order")
        for _ in 0..<6 { app.buttons["tracing.next"].tap() }
        XCTAssertEqual(example.label, "き")
        attachScreenshot(app, name: "Hiragana き four separate strokes")
        XCUIDevice.shared.orientation = .landscapeLeft
        // Tapping waits for rotation to settle before taking the landscape capture.
        app.buttons["tracing.restart"].tap()
        XCTAssertTrue(app.buttons["tracing.close"].isHittable)
        attachScreenshot(app, name: "Hiragana landscape")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["tracing.restart"].tap()
        app.buttons["tracing.close"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let last = app.buttons["tracing.glyph.ん"]
        for _ in 0..<8 {
            if last.exists && last.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(last.isHittable, app.debugDescription)
        last.tap()
        XCTAssertTrue(example.waitForExistence(timeout: 5))
        XCTAssertEqual(example.label, "ん")
        XCTAssertFalse(app.buttons["tracing.next"].isEnabled)
    }

    func testHiraganaRouteIsUnavailableOutsideJapanese() {
        let app = launch(language: "en", pack: "hiragana_tracing")
        XCTAssertTrue(app.staticTexts["bookshelf.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["tracing.glyph.あ"].exists)
    }

    func testAlphabetStillUsesExistingLetterGridAndControls() {
        let app = launch(language: "en", pack: "letter_tracing")
        let a = app.buttons["tracing.glyph.A"]
        XCTAssertTrue(a.waitForExistence(timeout: 10))
        a.tap()
        XCTAssertTrue(app.buttons["tracing.close"].waitForExistence(timeout: 10), app.debugDescription)
        let example = element("tracing.example", in: app)
        XCTAssertEqual(example.label, "A a")
        XCTAssertEqual(element("tracing.practice", in: app).label, "A a")
        attachScreenshot(app, name: "Generated uppercase and lowercase A a")
        XCTAssertFalse(app.buttons["tracing.previous"].isEnabled)
        app.buttons["tracing.next"].tap()
        XCTAssertEqual(example.label, "B b")
        XCTAssertTrue(app.buttons["tracing.previous"].isEnabled)
        app.buttons["tracing.close"].tap()
        XCTAssertTrue(a.waitForExistence(timeout: 5))
    }

    func testGeneratedLowercaseLoopsDotsAndDescenders() {
        let app = launch(language: "en", pack: "letter_tracing")
        let g = app.buttons["tracing.glyph.G"]
        XCTAssertTrue(g.waitForExistence(timeout: 10))
        g.tap()
        let example = element("tracing.example", in: app)
        XCTAssertTrue(example.waitForExistence(timeout: 10))
        XCTAssertEqual(example.label, "G g")
        attachScreenshot(app, name: "Generated G g and lowercase descender")
        app.buttons["tracing.next"].tap()
        app.buttons["tracing.next"].tap()
        XCTAssertEqual(example.label, "I i")
        attachScreenshot(app, name: "Generated I i with separate dot")
        app.buttons["tracing.next"].tap()
        XCTAssertEqual(example.label, "J j")
        attachScreenshot(app, name: "Generated J j descender and dot")
    }

    private func launch(language: String, pack: String? = nil, captureAnalytics: Bool = false, discountEligible: Bool? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestDisableAnalytics",
            "-hasCompletedOnboarding", "YES", "-appLanguage", language,
            "-appLanguageWasSelectedByUser", "YES", "-ttsEnabled", "NO", "-ttsDefaultSet", "YES"
        ]
        if let pack { app.launchArguments += ["-uiTestSelectedPack", pack] }
        if let discountEligible { app.launchArguments += ["-isDiscountEligible", discountEligible ? "YES" : "NO"] }
        if captureAnalytics {
            app.launchArguments += [
                "-uiTestRecordOnboardingAnalytics", "-hasRequestedReviewAfterFirstAccountOpen", "YES"
            ]
            app.launchEnvironment["ONBOARDING_ANALYTICS_CAPTURE"] = discountEligible == true ? "paywall-discount" : "paywall-regular"
        }
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let landscape = name.localizedCaseInsensitiveContains("landscape")
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return landscape ? frame.width > frame.height : frame.height > frame.width
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 10), .completed,
                       "The interface must finish rotating before capture")
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
