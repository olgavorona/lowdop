import SwiftUI

extension Notification.Name {
    /// Posted when the user completes a story and taps "Back to Bookshelf"
    /// from the story-complete celebration screen.
    static let returnToBookshelf = Notification.Name("returnToBookshelf")
}

struct ContentView: View {
    @EnvironmentObject var preferences: UserPreferences

    /// Tracks which pack the user selected from the bookshelf.
    /// `nil` means no pack is selected (show bookshelf).
    /// Non-nil means show the grid for that pack.
    /// NOT persisted — resets on every app launch so the user sees the bookshelf first.
    @State private var selectedPack: String? = nil

    var body: some View {
        Group {
            if !preferences.hasCompletedOnboarding {
                OnboardingView()
            } else if let _ = selectedPack {
                LabyrinthGridView(onBackToBookshelf: {
                    selectedPack = nil
                })
            } else {
                BookshelfView(onPackSelected: { packId in
                    selectedPack = packId
                })
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .returnToBookshelf)) { _ in
            selectedPack = nil
        }
    }
}
