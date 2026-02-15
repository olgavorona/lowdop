import SwiftUI

struct ContentView: View {
    @EnvironmentObject var preferences: UserPreferences

    var body: some View {
        if preferences.hasCompletedOnboarding {
            LabyrinthGridView()
        } else {
            OnboardingView()
        }
    }
}
