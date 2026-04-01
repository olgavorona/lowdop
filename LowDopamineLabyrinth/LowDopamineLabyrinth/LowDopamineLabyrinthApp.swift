import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .landscape
    }
}

@main
struct LowDopamineLabyrinthApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var preferences = UserPreferences()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var progressTracker = ProgressTracker()
    @StateObject private var ttsService = TTSService()

    init() {
        Analytics.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                preferences: preferences,
                subscriptionManager: subscriptionManager,
                progressTracker: progressTracker,
                ttsService: ttsService
            )
        }
    }
}

struct RootView: View {
    @ObservedObject var preferences: UserPreferences
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject var progressTracker: ProgressTracker
    @ObservedObject var ttsService: TTSService
    @StateObject private var gameViewModel: GameViewModel

    init(preferences: UserPreferences,
         subscriptionManager: SubscriptionManager,
         progressTracker: ProgressTracker,
         ttsService: TTSService) {
        self.preferences = preferences
        self.subscriptionManager = subscriptionManager
        self.progressTracker = progressTracker
        self.ttsService = ttsService
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
            .environmentObject(gameViewModel)
            .onAppear { requestLandscape() }
            .fullScreenCover(isPresented: Binding(
                get: { !preferences.hasCompletedOnboarding },
                set: { _ in }
            )) {
                OnboardingView {
                    preferences.hasCompletedOnboarding = true
                }
                .environmentObject(preferences)
                .environmentObject(subscriptionManager)
            }
    }

    private func requestLandscape() {
        guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0 is UIWindowScene }) as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
    }
}
