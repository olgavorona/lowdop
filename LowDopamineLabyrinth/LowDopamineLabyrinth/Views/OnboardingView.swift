import SwiftUI
import StoreKit
import UIKit

private enum OnboardingLanguageConfiguration {
    static var audioPackCanBeSkipped: Bool {
#if targetEnvironment(simulator) && DEBUG
        !ProcessInfo.processInfo.arguments.contains("-useLocalAudioMockServer")
#elseif targetEnvironment(simulator)
        true
#else
        false
#endif
    }
}

// MARK: - OnboardingViewModel

/// Lightweight state model for onboarding page navigation.
/// Extracted to allow unit testing without SwiftUI environment.
final class OnboardingViewModel: ObservableObject {
    static let totalPages: Int = 6
    static let parentalGatePage: Int = 4

    enum NavigationResult: Equatable {
        case changed
        case blockedByParentalGate
        case unchanged
    }

    // Keep page IDs stable for analytics when the language page is omitted.
    let firstPage: Int
    let variant: OnboardingExperimentVariant?
    var visiblePages: [Int] {
        (firstPage..<Self.totalPages).filter { $0 != variant?.omittedPage }
    }
    var showsLanguagePicker: Bool { firstPage == 0 }
    var nextPage: Int { visiblePages.first { $0 > currentPage } ?? currentPage }

    @Published var currentPage: Int

    init(preferredLanguages: [String] = Locale.preferredLanguages, variant: OnboardingExperimentVariant? = nil) {
        self.variant = variant
        let primaryLanguage = preferredLanguages.first?
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-").first?.lowercased()
        firstPage = primaryLanguage == "en" ? 1 : 0
        currentPage = firstPage
    }

    var isOnLastPage: Bool {
        currentPage == Self.totalPages - 1
    }

    var requiresParentalGateBeforeAdvance: Bool {
        currentPage == Self.parentalGatePage
    }

    func attemptAdvance() -> NavigationResult {
        attemptNavigate(to: nextPage)
    }

    func attemptNavigate(to requestedPage: Int) -> NavigationResult {
        let clampedPage = visibleDestination(for: requestedPage)

        guard clampedPage != currentPage else {
            return .unchanged
        }

        if currentPage == Self.parentalGatePage && clampedPage > currentPage {
            return .blockedByParentalGate
        }

        currentPage = clampedPage
        return .changed
    }

    func completeParentalGateAdvance() {
        currentPage = nextPage
    }

    func completeParentalGateNavigation(to requestedPage: Int) {
        currentPage = visibleDestination(for: requestedPage)
    }

    private func visibleDestination(for requestedPage: Int) -> Int {
        let clampedPage = min(max(requestedPage, firstPage), Self.totalPages - 1)
        if visiblePages.contains(clampedPage) { return clampedPage }
        if clampedPage > currentPage {
            return visiblePages.first { $0 >= clampedPage } ?? currentPage
        }
        return visiblePages.last { $0 <= clampedPage } ?? currentPage
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var ttsService: TTSService
    @EnvironmentObject var languageAudioPackManager: LanguageAudioPackManager
    @EnvironmentObject var reviewRequestManager: ReviewRequestManager

    var onComplete: (() -> Void)? = nil

    @StateObject private var viewModel: OnboardingViewModel
    @State private var showParentalGate = false
    @State private var parentalGateWasPassed = false
    @State private var isPurchasing = false
    @State private var tabSelection: Int
    @State private var pendingPageAfterGate: Int?
    @State private var pendingNavigationMethod: OnboardingAnalyticsTracker.Method?
    @State private var tabViewResetToken = UUID()
    @State private var didPlayTutorialVoiceover = false
    @State private var onboardingAnalytics: OnboardingAnalyticsTracker

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
        let variant = OnboardingExperiment.assignedVariant()
        let model = OnboardingViewModel(variant: variant)
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestDisableAnalytics"), arguments.contains("-uiTestPreviewOnboardingPaywall") {
            model.currentPage = OnboardingViewModel.totalPages - 1
        }
#endif
        _viewModel = StateObject(wrappedValue: model)
        _tabSelection = State(initialValue: model.currentPage)
        _onboardingAnalytics = State(initialValue: OnboardingAnalyticsTracker(variant: variant))
    }

    private var currentPage: Int { viewModel.currentPage }
    private let totalPages = OnboardingViewModel.totalPages
    private var canContinueFromLanguagePage: Bool {
        OnboardingLanguageConfiguration.audioPackCanBeSkipped
            || preferences.appLanguage.audioPackID == nil
            || preferences.appLanguage == .english
            || languageAudioPackManager.downloadedLanguages.contains(preferences.appLanguage)
    }
    private var pageSelection: Binding<Int> {
        Binding(
            get: { tabSelection },
            set: { requestedPage in
                guard currentPage != 0 || requestedPage <= 0 || canContinueFromLanguagePage else {
                    resetTabViewSelection()
                    return
                }
                navigate(to: requestedPage, method: .swipe)
            }
        )
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(viewModel.visiblePages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? AppColor.accentGreen : AppColor.textFaint)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 8)

                // Pages
                TabView(selection: pageSelection) {
                    if viewModel.showsLanguagePicker {
                        OnboardingLanguagePage(analytics: onboardingAnalytics, onContinue: {
                            advancePage(method: .button)
                        })
                        .tag(0)
                    }
                    OnboardingPage1(
                        isActive: currentPage == 1,
                        onComplete: { advancePage(method: .tutorialCompleted) },
                        onSkip: { advancePage(method: .tutorialSkipped) },
                        analytics: onboardingAnalytics,
                        didPlayVoiceover: $didPlayTutorialVoiceover
                    )
                        .tag(1)
                    if viewModel.visiblePages.contains(2) {
                        OnboardingPage2()
                            .tag(2)
                    }
                    if viewModel.visiblePages.contains(3) {
                        OnboardingPage3()
                            .tag(3)
                    }
                    OnboardingPage4(analytics: onboardingAnalytics, onSelect: {
                        advancePage(method: .difficultyCard)
                    })
                    .tag(4)
                    OnboardingPage5(
                        isPurchasing: $isPurchasing,
                        variant: viewModel.variant,
                        onGetFullAccess: {
                            let product = subscriptionManager.fullAccessProduct
                            guard let product else { return }
                            Task {
                                isPurchasing = true
                                Analytics.send("initial_paywall_purchase_started", with: [
                                    "product_id": product.id,
                                    "localized_price": product.displayPrice,
                                    "currency": product.priceFormatStyle.currencyCode,
                                    "source": PaywallSource.onboarding.rawValue,
                                    "paywall_type": "regular",
                                    "difficulty": preferences.difficultyLevel.rawValue,
                                    "app_locale": preferences.appLanguage.rawValue
                                ])
                                let success = await subscriptionManager.purchase(product)
                                isPurchasing = false
                                if success {
                                    Analytics.send("initial_paywall_purchase_success", with: [
                                        "product_id": product.id,
                                        "localized_price": product.displayPrice,
                                        "currency": product.priceFormatStyle.currencyCode,
                                        "source": PaywallSource.onboarding.rawValue,
                                        "paywall_type": "regular",
                                        "difficulty": preferences.difficultyLevel.rawValue,
                                        "app_locale": preferences.appLanguage.rawValue
                                    ])
                                    completeOnboarding()
                                    reviewRequestManager.requestAfterSuccessfulOnboardingPurchase(
                                        isPremium: subscriptionManager.isPremium
                                    )
                                } else {
                                    Analytics.send("initial_paywall_purchase_cancelled", with: [
                                        "product_id": product.id,
                                        "localized_price": product.displayPrice,
                                        "currency": product.priceFormatStyle.currencyCode,
                                        "source": PaywallSource.onboarding.rawValue,
                                        "paywall_type": "regular",
                                        "difficulty": preferences.difficultyLevel.rawValue,
                                        "app_locale": preferences.appLanguage.rawValue
                                    ])
                                }
                            }
                        },
                        onStartFree: {
                            Analytics.send("Onboarding.startFreeTapped")
                            completeOnboarding()
                        },
                        onRestore: {
                            Task { await subscriptionManager.restorePurchases() }
                        }
                    )
                    .tag(5)
                }
                .id(tabViewResetToken)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Next button (hidden on last page — it has its own CTAs)
                if !viewModel.isOnLastPage && currentPage != 0 && currentPage != 1 {
                    Button(action: { advancePage(method: .button) }) {
                        Text("Next")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppColor.accentGreen)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 28)
                    .transition(.opacity)
                }
            }
        }
        .environment(\.locale, preferences.appLanguage.locale)
        .environment(\.layoutDirection, preferences.appLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
        .fullScreenCover(isPresented: $showParentalGate, onDismiss: finishParentalGateDismissal) {
            ParentalGateView(purpose: .paywall) {
                let method = pendingNavigationMethod ?? .button
                onboardingAnalytics.parentalGateFinished(
                    passed: true, method: method,
                    language: preferences.appLanguage, difficulty: preferences.difficultyLevel
                )
                parentalGateWasPassed = true
                showParentalGate = false
            } onCancel: {
                onboardingAnalytics.parentalGateFinished(
                    passed: false, method: pendingNavigationMethod ?? .button,
                    language: preferences.appLanguage, difficulty: preferences.difficultyLevel
                )
                parentalGateWasPassed = false
                showParentalGate = false
            }
        }
        .onAppear {
            tabSelection = viewModel.currentPage
            onboardingAnalytics.experimentExposed(
                page: currentPage, language: preferences.appLanguage, difficulty: preferences.difficultyLevel
            )
            if !viewModel.showsLanguagePicker {
                onboardingAnalytics.languagePickerSkipped(
                    language: preferences.appLanguage, difficulty: preferences.difficultyLevel
                )
            }
            recordPageShown()
        }
        .onChange(of: viewModel.currentPage) { newValue in
            tabSelection = newValue
            recordPageShown()
        }
        .task {
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
        }
    }

    private func advancePage(method: OnboardingAnalyticsTracker.Method) {
        let requestedPage = viewModel.nextPage
        navigate(to: requestedPage, method: method)
    }

    private func finishParentalGateDismissal() {
        let passed = parentalGateWasPassed
        let destination = pendingPageAfterGate ?? viewModel.nextPage
        let method = pendingNavigationMethod ?? .button
        parentalGateWasPassed = false
        pendingPageAfterGate = nil
        pendingNavigationMethod = nil
        guard passed else {
            resetTabViewSelection()
            return
        }
        // Keep the presenting page alive until the cover has finished dismissing.
        onboardingAnalytics.transitioned(
            from: currentPage, to: destination, method: method,
            language: preferences.appLanguage, difficulty: preferences.difficultyLevel
        )
        withAnimation {
            viewModel.completeParentalGateNavigation(to: destination)
        }
        tabSelection = viewModel.currentPage
        recordPageShown()
    }

    private func navigate(to requestedPage: Int, method: OnboardingAnalyticsTracker.Method) {
        let previousPage = currentPage
        let result = viewModel.attemptNavigate(to: requestedPage)
        switch result {
        case .changed:
            onboardingAnalytics.transitioned(
                from: previousPage, to: currentPage, method: method,
                language: preferences.appLanguage, difficulty: preferences.difficultyLevel
            )
            showParentalGate = false
            tabSelection = viewModel.currentPage
            recordPageShown()
            if requestedPage == 1,
               OnboardingLanguageConfiguration.audioPackCanBeSkipped,
               preferences.appLanguage != .english {
                Analytics.send("Language.audioPackBypassed", with: [
                    "language": preferences.appLanguage.rawValue,
                    "app_locale": preferences.appLanguage.rawValue,
                    "source": "simulator"
                ])
            }
        case .blockedByParentalGate:
            parentalGateWasPassed = false
            pendingPageAfterGate = min(max(requestedPage, 0), totalPages - 1)
            pendingNavigationMethod = method
            onboardingAnalytics.forwardAttempt(
                from: previousPage, to: pendingPageAfterGate ?? previousPage, method: method,
                language: preferences.appLanguage, difficulty: preferences.difficultyLevel
            )
            resetTabViewSelection()
            showParentalGate = true
            onboardingAnalytics.parentalGateShown(
                method: method, language: preferences.appLanguage, difficulty: preferences.difficultyLevel
            )
        case .unchanged:
            resetTabViewSelection()
            break
        }
    }

    private func recordPageShown() {
        let firstAppearance = onboardingAnalytics.screenShown(
            page: currentPage, language: preferences.appLanguage, difficulty: preferences.difficultyLevel
        )
        if firstAppearance && currentPage == totalPages - 1 {
            Analytics.send("initial_paywall_view", with: [
                "source": PaywallSource.onboarding.rawValue,
                "paywall_type": "regular",
                "product_id": subscriptionManager.fullAccessProduct?.id ?? "",
                "localized_price": subscriptionManager.fullAccessProduct?.displayPrice ?? "",
                "currency": subscriptionManager.fullAccessProduct?.priceFormatStyle.currencyCode ?? "",
                "app_locale": preferences.appLanguage.rawValue,
                "onboarding_analytics_version": "2"
            ])
        }
    }

    private func resetTabViewSelection() {
        tabSelection = viewModel.currentPage
        tabViewResetToken = UUID()
    }

    private func completeOnboarding() {
        onboardingAnalytics.completed(language: preferences.appLanguage, difficulty: preferences.difficultyLevel)
        preferences.hasCompletedOnboarding = true
        onComplete?()
    }
}

// MARK: - Screen 1: Choose Language

private struct OnboardingLanguagePage: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var languageAudioPackManager: LanguageAudioPackManager
    let analytics: OnboardingAnalyticsTracker
    let onContinue: () -> Void

    @State private var isPreparingLanguage = false

    private func localizedText(_ source: String, replacing values: [String: String] = [:]) -> String {
        AppLocalization.text(source, language: preferences.appLanguage, replacing: values)
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if geometry.size.width > geometry.size.height {
                    wideLayout(size: geometry.size)
                } else {
                    compactLayout(size: geometry.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 28)
        }
    }

    private func wideLayout(size: CGSize) -> some View {
        HStack(spacing: 36) {
            languageIllustration
                .frame(maxWidth: size.width * 0.48)
                .frame(maxHeight: size.height * 0.72)

            VStack(alignment: .leading, spacing: 18) {
                Spacer(minLength: 0)
                heading(alignment: .leading)
                languagePicker
                languageAction
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
        .frame(maxWidth: 1100, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactLayout(size: CGSize) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            heading(alignment: .center)
            languageIllustration
                .frame(maxWidth: 560)
                .frame(height: min(size.height * 0.38, 300))
            languagePicker
            languageAction
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var languageIllustration: some View {
        Image("language_selection")
            .resizable()
            .scaledToFit()
            .accessibilityLabel(Text(localizedText("Denny welcomes you to choose a language")))
    }

    private func heading(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 10) {
            Text(localizedText("Choose your language"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .multilineTextAlignment(alignment == .leading ? .leading : .center)

            Text(localizedText(
                "Choose the language for menus, stories, and narration. You can change it anytime in Settings."
            ))
            .font(.system(size: 17, design: .rounded))
            .foregroundColor(AppColor.textSecondary)
            .multilineTextAlignment(alignment == .leading ? .leading : .center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
    }

    private var languagePicker: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    preferences.appLanguage = language
                    analytics.languageChanged(to: language, difficulty: preferences.difficultyLevel)
                } label: {
                    if preferences.appLanguage == language {
                        Label {
                            Text(verbatim: language.displayName)
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text(verbatim: language.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppColor.accentBlue)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedText("App language"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppColor.textSecondary)
                    Text(verbatim: preferences.appLanguage.displayName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(localizedText("App language") + ": " + preferences.appLanguage.displayName))
        .accessibilityIdentifier("onboarding.languagePicker")
    }

    private var languageAction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: handleLanguageAction) {
                HStack(spacing: 10) {
                    if isPreparingLanguage,
                       languageAudioPackManager.progress[preferences.appLanguage] == nil {
                        ProgressView()
                            .tint(.white)
                    } else if let progress = languageAudioPackManager.progress[preferences.appLanguage] {
                        ProgressView(value: progress)
                            .tint(.white)
                    }

                    Text(languageActionTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColor.accentGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(isPreparingLanguage || languageAudioPackManager.progress[preferences.appLanguage] != nil)
            .accessibilityIdentifier("onboarding.languageAction")

            if let error = languageAudioPackManager.errors[preferences.appLanguage] {
                Text(localizedText(error))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.red)
            }
        }
    }

    private var languageActionTitle: String {
        if OnboardingLanguageConfiguration.audioPackCanBeSkipped {
            return localizedText("Continue")
        }
        if preferences.appLanguage.audioPackID == nil {
            return localizedText("Continue")
        }
        if isPreparingLanguage || languageAudioPackManager.progress[preferences.appLanguage] != nil {
            return localizedText("Downloading narration…")
        }
        if preferences.appLanguage == .english
            || languageAudioPackManager.downloadedLanguages.contains(preferences.appLanguage) {
            return localizedText("Continue")
        }
        return localizedText(
            #"Download \(language.displayName) narration"#,
            replacing: [
                #"\(language.displayName)"#: localizedText(preferences.appLanguage.displayName)
            ]
        )
    }

    private func handleLanguageAction() {
        let language = preferences.appLanguage
        if OnboardingLanguageConfiguration.audioPackCanBeSkipped {
            onContinue()
            return
        }

        guard language != .english,
              language.audioPackID != nil,
              !languageAudioPackManager.downloadedLanguages.contains(language) else {
            onContinue()
            return
        }

        guard !isPreparingLanguage else { return }
        isPreparingLanguage = true
        Task {
            await languageAudioPackManager.download(language)
            isPreparingLanguage = false
        }
    }
}

// MARK: - Screen 2: Draw the Path

private struct OnboardingPage1: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService

    let isActive: Bool
    let onComplete: () -> Void
    let onSkip: () -> Void
    let analytics: OnboardingAnalyticsTracker
    @Binding var didPlayVoiceover: Bool

    @StateObject private var tutorialViewModel = LabyrinthViewModel(
        labyrinth: onboardingTutorialLabyrinth,
        completionRadiusBase: 80
    )
    @State private var didAdvance = false

    var body: some View {
        GeometryReader { geo in
            if usesPhoneSideInstruction(for: geo.size) {
                phoneSideInstructionLayout
            } else {
                defaultLayout
            }
        }
        .onAppear(perform: activateTutorialIfNeeded)
        .onChange(of: isActive) { active in
            if active {
                activateTutorialIfNeeded()
            } else {
                ttsService.stop()
            }
        }
        .onDisappear {
            ttsService.stop()
        }
        .onChange(of: tutorialViewModel.isCompleted) { completed in
            guard completed, !didAdvance else { return }
            didAdvance = true
            analytics.tutorialOutcome(completed: true, method: .tutorialCompleted,
                                      language: preferences.appLanguage, difficulty: preferences.difficultyLevel)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onComplete()
                didAdvance = false
            }
        }
    }

    private func activateTutorialIfNeeded() {
        guard isActive else { return }
        tutorialViewModel.reset()
        guard !didPlayVoiceover else { return }

        ttsService.setLanguage(preferences.appLanguage)
        didPlayVoiceover = true
        let tutorialInstruction = LabyrinthLoader.shared.localizedNarration(
            "Draw the path with your finger or Apple Pencil. Start at the green go marker."
        )
        let didStartAudio = ttsService.playAudio(
            "onboarding_trace_intro.mp3",
            localizedText: tutorialInstruction
        )
        analytics.tutorialAudioStarted(didStartAudio, language: preferences.appLanguage,
                                       difficulty: preferences.difficultyLevel)
    }

    private var defaultLayout: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 12)

            instructionText(alignment: .center)
                .padding(.horizontal, 40)

            OnboardingTutorialMazeCard(viewModel: tutorialViewModel)
                .frame(maxWidth: 620)
                .frame(height: 360)
                .padding(.horizontal, 24)

            Spacer(minLength: 8)

            Button(action: {
                onSkip()
            }) {
                skipButtonLabel
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }

    private var phoneSideInstructionLayout: some View {
        HStack(spacing: 14) {
            OnboardingTutorialMazeCard(viewModel: tutorialViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Spacer(minLength: 0)

                instructionText(alignment: .leading)

                Button(action: {
                    onSkip()
                }) {
                    skipButtonLabel
                }

                Spacer(minLength: 0)
            }
            .frame(width: 220)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func usesPhoneSideInstruction(for size: CGSize) -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone && size.width > size.height
    }

    private func instructionText(alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .leading ? .leading : .center, spacing: 8) {
            Text("Draw the Path")
                .font(.system(size: alignment == .leading ? 24 : 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .multilineTextAlignment(alignment)

            Text("Use your finger or Apple Pencil to trace the route.")
                .font(.system(size: alignment == .leading ? 15 : 17, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var skipButtonLabel: some View {
        Text("Skip for Now")
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(AppColor.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

private struct OnboardingTutorialMazeCard: View {
    @ObservedObject var viewModel: LabyrinthViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#DFF4FF") ?? .blue.opacity(0.18),
                                Color.white,
                                Color(hex: "#E9FFF4") ?? .green.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                ZStack {
                    OceanPatternView()
                        .opacity(0.08)

                    viewModel.mazePath
                        .stroke(
                            Color(hex: "#15A6C7") ?? .blue,
                            style: StrokeStyle(lineWidth: 16 * viewModel.scale, lineCap: .round, lineJoin: .round)
                        )

                    viewModel.mazePath
                        .stroke(
                            Color.white.opacity(0.95),
                            style: StrokeStyle(lineWidth: 10 * viewModel.scale, lineCap: .round, lineJoin: .round)
                        )

                    CharacterMarkerView(
                        character: viewModel.labyrinth.characterStart,
                        scale: max(viewModel.scale, 1.0),
                        isStart: true,
                        clipToCircle: true,
                        arrowAngle: viewModel.startArrowAngle
                    )
                    .position(viewModel.startPoint)

                    CharacterMarkerView(
                        character: viewModel.labyrinth.characterEnd,
                        scale: max(viewModel.scale, 1.0),
                        isStart: false,
                        clipToCircle: false
                    )
                    .position(viewModel.endPoint)

                    DrawingCanvas(viewModel: viewModel, tolerance: 1.0)

                }
                .padding(18)
            }
            .onAppear {
                viewModel.canvasSize = CGSize(width: geo.size.width - 36, height: geo.size.height - 36)
                viewModel.setupValidator(tolerance: 1.0)
            }
            .onChange(of: geo.size) { newSize in
                viewModel.canvasSize = CGSize(width: newSize.width - 36, height: newSize.height - 36)
                viewModel.setupValidator(tolerance: 1.0)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

private struct OnboardingStartHint: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.point.left.fill")
                .font(.system(size: 12, weight: .bold))
            Text("Start here")
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppColor.accentGreen)
        .cornerRadius(12)
        .scaleEffect(pulse ? 1.05 : 0.95)
        .shadow(color: AppColor.accentGreen.opacity(0.35), radius: pulse ? 10 : 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Screen 2: 100 Labyrinths

private struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("100+")
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundColor(AppColor.accentGreen)

            Text("Labyrinths to Explore")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.bottom, 12)

            VStack(spacing: 14) {
                OnboardingFeatureRow(icon: "dial.low.fill",  label: "3 difficulty levels for every child")
                OnboardingFeatureRow(icon: "pencil.line",    label: "Develop pre-writing skills")
                OnboardingFeatureRow(icon: "arrow.clockwise",label: "Seasonal content every month")
            }
            .padding(.horizontal, 48)

            Spacer()
        }
    }
}

// MARK: - Screen 3: Calm & Focused

private struct OnboardingPage3: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            bundleImage("onboarding_maze_screenshot")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 420)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

            Text("Calm & Focused")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.bottom, 8)

            VStack(spacing: 12) {
                OnboardingFeatureRow(icon: "checkmark.circle.fill", label: "No ads, ever")
                OnboardingFeatureRow(icon: "checkmark.circle.fill", label: "No timers or pressure")
                OnboardingFeatureRow(icon: "checkmark.circle.fill", label: "Works offline")
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Screen 4: Difficulty

private struct OnboardingPage4: View {
    @EnvironmentObject var preferences: UserPreferences
    let analytics: OnboardingAnalyticsTracker
    let onSelect: () -> Void

    private let levelColors: [DifficultyLevel: [Color]] = [
        .easy:   [Color(hex: "#4FC3F7") ?? .blue,   Color(hex: "#29B6F6") ?? .blue],
        .medium: [Color(hex: "#29B6F6") ?? .blue,   Color(hex: "#039BE5") ?? .blue],
        .hard:   [Color(hex: "#039BE5") ?? .blue,   Color(hex: "#0277BD") ?? .blue],
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Set the Difficulty")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.bottom, 10)

            Text("Choose what feels right for your child")
                .font(.system(size: 17, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .padding(.bottom, 32)

            HStack(spacing: 12) {
                ForEach(DifficultyLevel.allCases, id: \.self) { level in
                    DifficultyCard(
                        level: level,
                        colors: levelColors[level] ?? [.blue, .blue],
                        samplePath: loadSamplePath(for: level),
                        isSelected: preferences.difficultyLevel == level
                    ) {
                        preferences.difficultyLevel = level
                        analytics.difficultyChanged(to: level, language: preferences.appLanguage)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSelect() }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func loadSamplePath(for level: DifficultyLevel) -> String {
        guard let url = Bundle.main.url(forResource: "difficulty_samples", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let samples = try? JSONDecoder().decode([String: String].self, from: data) else {
            return ""
        }
        return samples[level.rawValue] ?? ""
    }
}

// MARK: - Screen 5: Soft Paywall

private struct OnboardingPage5: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var isPurchasing: Bool
    let variant: OnboardingExperimentVariant?
    let onGetFullAccess: () -> Void
    let onStartFree: () -> Void
    let onRestore: () -> Void
    private var product: Product? { subscriptionManager.fullAccessProduct }

    var body: some View {
        paywallContent
        .onAppear {
            subscriptionManager.markInitialPaywallSeen()
        }
    }

    private var paywallContent: some View {
        PaywallLayout {
            PaywallHero(
                title: "Ready to Explore?",
                subtitle: "First 6 mazes are free.\nUnlock everything for your child."
            )
            VStack(alignment: .leading, spacing: 16) {
                ForEach(variant?.paywallMessages ?? ["Forever access"], id: \.self) { message in
                    PaywallBenefitRow(message: message)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 26)
        } offer: {
            if let product {
                LifetimePaywallCard(product: product)
            } else {
                ProgressView().frame(height: 90)
            }
        } actions: {
            Button(action: onGetFullAccess) {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Get Full Access")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
            }
            .buttonStyle(PaywallPrimaryButtonStyle())
            .disabled(isPurchasing || product == nil)
            .opacity((isPurchasing || product == nil) ? 0.6 : 1)
            .accessibilityIdentifier("paywall.purchase")

            Button(action: onStartFree) {
                Text("Start for Free →")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColor.textFaint.opacity(0.3)))
            }
            .buttonStyle(.plain)
        } footer: {
            Button(action: onRestore) {
                Text("Restore Purchases")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(minHeight: 36)
            }
            .foregroundColor(AppColor.textTertiary)
            HStack(spacing: 8) {
                Link("Privacy Policy", destination: URL(string: "https://olgavorona.github.io/lowdop/privacy")!)
                Text("·")
                Link("Terms of Use", destination: URL(string: "https://olgavorona.github.io/lowdop/terms")!)
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundColor(AppColor.textTertiary)
        }
    }

}

// MARK: - Shared helpers

private struct OnboardingFeatureRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColor.accentGreen)
                .frame(width: 24)
            Text(LocalizedStringKey(label))
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
        }
    }
}

/// Load a PNG from the app bundle (Resources/, not .xcassets).
private func bundleImage(_ name: String) -> Image {
    if let path = Bundle.main.path(forResource: name, ofType: "png"),
       let ui = UIImage(contentsOfFile: path) {
        return Image(uiImage: ui)
    }
    return Image(systemName: "photo")
}

private let onboardingTutorialLabyrinth = Labyrinth(
    id: "onboarding_tutorial_easy",
    ageRange: "3-6",
    difficulty: "easy",
    theme: "ocean",
    title: "Draw the Path",
    storySetup: "Denny is ready to show how tracing works.",
    instruction: "Draw the path with your finger or Apple Pencil.",
    ttsInstruction: "Draw the path with your finger or Apple Pencil. Start at the green go marker.",
    characterStart: LabyrinthCharacter(
        type: "character",
        description: "Denny the crab at the start",
        position: "left",
        name: nil,
        imageAsset: "denny"
    ),
    characterEnd: LabyrinthCharacter(
        type: "character",
        description: "Finn cheering at the finish",
        position: "right",
        name: "Finn",
        imageAsset: "finn"
    ),
    educationalQuestion: "",
    funFact: "",
    completionMessage: "Nice work!",
    pathData: PathData(
        svgPath: "M 20 40 L 160 40 M 20 40 L 20 180 M 160 40 L 300 40 M 160 180 L 300 180 M 300 40 L 440 40 M 300 180 L 440 180 M 440 40 L 580 40 M 580 40 L 580 180 M 20 320 L 160 320 M 20 180 L 20 320 M 160 180 L 300 180 M 300 180 L 300 320 M 300 180 L 440 180 M 300 180 L 300 320 M 580 180 L 580 320 M 20 320 L 160 320 M 20 460 L 160 460 M 20 320 L 20 460 M 160 460 L 300 460 M 440 320 L 440 460 M 300 460 L 440 460 M 580 320 L 580 460 M 440 460 L 580 460 M 440 320 L 440 460",
        solutionPath: "M 90 390 L 230 390 L 370 390 L 370 250 L 510 250 L 510 110",
        width: 40,
        complexity: "easy",
        mazeType: "grid",
        startPoint: PointData(x: 90, y: 390),
        endPoint: PointData(x: 510, y: 110),
        segments: [
            SegmentData(start: PointData(x: 90, y: 110), end: PointData(x: 230, y: 110)),
            SegmentData(start: PointData(x: 90, y: 110), end: PointData(x: 90, y: 250)),
            SegmentData(start: PointData(x: 230, y: 110), end: PointData(x: 370, y: 110)),
            SegmentData(start: PointData(x: 370, y: 110), end: PointData(x: 510, y: 110)),
            SegmentData(start: PointData(x: 510, y: 110), end: PointData(x: 510, y: 250)),
            SegmentData(start: PointData(x: 90, y: 250), end: PointData(x: 230, y: 250)),
            SegmentData(start: PointData(x: 230, y: 250), end: PointData(x: 230, y: 390)),
            SegmentData(start: PointData(x: 370, y: 250), end: PointData(x: 510, y: 250)),
            SegmentData(start: PointData(x: 370, y: 250), end: PointData(x: 370, y: 390)),
            SegmentData(start: PointData(x: 510, y: 250), end: PointData(x: 510, y: 390)),
            SegmentData(start: PointData(x: 90, y: 390), end: PointData(x: 230, y: 390)),
            SegmentData(start: PointData(x: 230, y: 390), end: PointData(x: 370, y: 390)),
        ],
        canvasWidth: 600,
        canvasHeight: 500,
        controlPoints: [],
        items: nil,
        avoidItems: nil
    ),
    visualTheme: VisualTheme(
        backgroundColor: "#6CCFF6",
        decorativeElements: ["waves", "bubbles"]
    ),
    location: "Tutorial Reef",
    audioInstruction: nil,
    audioCompletion: nil,
    itemRule: nil,
    itemEmoji: nil
)

// MARK: - DifficultyCard (used by LabyrinthGridView + OnboardingPage4)

struct DifficultyCard: View {
    let level: DifficultyLevel
    let colors: [Color]
    let samplePath: String
    var isSelected: Bool = false
    let action: () -> Void

    private var levelNumber: Int {
        switch level {
        case .easy:   return 1
        case .medium: return 2
        case .hard:   return 3
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    if !samplePath.isEmpty {
                        GeometryReader { geo in
                            let scale = min(geo.size.width, geo.size.height) / 600
                            SVGPathParser.parse(samplePath, scale: scale)
                                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                        }
                        .padding(8)
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .padding(6)
                    }
                }

                Text(LocalizedStringKey(level.displayName))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < levelNumber ? colors[0] : Color.gray.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
