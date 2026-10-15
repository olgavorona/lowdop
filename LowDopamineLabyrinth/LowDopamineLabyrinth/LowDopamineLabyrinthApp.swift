import SwiftUI

@main
struct LowDopamineLabyrinthApp: App {
    @StateObject private var preferences = UserPreferences()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var progressTracker = ProgressTracker()
    @StateObject private var ttsService = TTSService()
    @StateObject private var languageAudioPackManager = LanguageAudioPackManager.shared
    @StateObject private var reviewRequestManager = ReviewRequestManager()

    init() {
        Analytics.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                preferences: preferences,
                subscriptionManager: subscriptionManager,
                progressTracker: progressTracker,
                ttsService: ttsService,
                languageAudioPackManager: languageAudioPackManager,
                reviewRequestManager: reviewRequestManager
            )
            .environment(\.locale, preferences.appLanguage.locale)
        }
    }
}

struct RootView: View {
    @ObservedObject var preferences: UserPreferences
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject var progressTracker: ProgressTracker
    @ObservedObject var ttsService: TTSService
    @ObservedObject var languageAudioPackManager: LanguageAudioPackManager
    @ObservedObject var reviewRequestManager: ReviewRequestManager
    @StateObject private var gameViewModel: GameViewModel
    @State private var didConfigureUITestEnvironment = false

    init(preferences: UserPreferences,
         subscriptionManager: SubscriptionManager,
         progressTracker: ProgressTracker,
         ttsService: TTSService,
         languageAudioPackManager: LanguageAudioPackManager,
         reviewRequestManager: ReviewRequestManager) {
        self.preferences = preferences
        self.subscriptionManager = subscriptionManager
        self.progressTracker = progressTracker
        self.ttsService = ttsService
        self.languageAudioPackManager = languageAudioPackManager
        self.reviewRequestManager = reviewRequestManager
        LabyrinthLoader.shared.setLanguage(preferences.appLanguage)
        _gameViewModel = StateObject(wrappedValue: GameViewModel(
            preferences: preferences,
            subscriptionManager: subscriptionManager,
            progressTracker: progressTracker
        ))
    }

    var body: some View {
        ContentView()
            .environmentObject(preferences)
            .environmentObject(subscriptionManager)
            .environmentObject(progressTracker)
            .environmentObject(ttsService)
            .environmentObject(languageAudioPackManager)
            .environmentObject(reviewRequestManager)
            .environmentObject(gameViewModel)
            .onAppear {
                ttsService.setLanguage(preferences.appLanguage)
                configureUITestEnvironmentIfNeeded()
            }
            .onChange(of: preferences.appLanguage) { language in
                ttsService.setLanguage(language)
                LabyrinthLoader.shared.setLanguage(language)
                gameViewModel.reloadForLanguageChange()
            }
            .fullScreenCover(isPresented: Binding(
                get: { !preferences.hasCompletedOnboarding },
                set: { _ in }
            )) {
                OnboardingView {
                    preferences.hasCompletedOnboarding = true
                }
                .environmentObject(preferences)
                .environmentObject(subscriptionManager)
                .environmentObject(ttsService)
                .environmentObject(languageAudioPackManager)
                .environmentObject(reviewRequestManager)
            }
    }

    private func configureUITestEnvironmentIfNeeded() {
        guard !didConfigureUITestEnvironment else { return }
        didConfigureUITestEnvironment = true

        guard ProcessInfo.processInfo.arguments.contains("-uiTestShowCompletionForLastLevel") else {
            return
        }

        preferences.hasCompletedOnboarding = true
        preferences.ttsEnabled = false
        preferences.difficultyLevel = .easy
        subscriptionManager.isPremium = true
    }
}
