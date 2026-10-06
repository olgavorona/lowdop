import SwiftUI

extension Notification.Name {
    /// Posted when the user completes a story and taps "Back to Bookshelf"
    /// from the story-complete celebration screen.
    static let returnToBookshelf = Notification.Name("returnToBookshelf")
}

enum AppDeepLink {
    static func packID(for url: URL) -> String? {
        guard url.scheme?.lowercased() == "dennysmazes" else { return nil }

        switch url.host?.lowercased() {
        case "fall": return "fall_adventures"
        default: return nil
        }
    }
}

struct ContentView: View {
    /// Tracks which pack the user selected from the bookshelf.
    /// `nil` means no pack is selected (show bookshelf).
    /// Non-nil means show the grid for that pack.
    /// NOT persisted — resets on every app launch so the user sees the bookshelf first.
    @State private var selectedPack: String? = ContentView.initialSelectedPack

    private static var initialSelectedPack: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let packFlagIndex = arguments.firstIndex(of: "-uiTestSelectedPack"),
              packFlagIndex + 1 < arguments.count else {
            return nil
        }
        return arguments[packFlagIndex + 1]
    }

    var body: some View {
        Group {
            if selectedPack == "letter_tracing" {
                LetterGridView(onBackToBookshelf: {
                    selectedPack = nil
                })
            } else if let packId = selectedPack {
                LabyrinthGridView(packId: packId, onBackToBookshelf: {
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
        .onOpenURL { url in
            guard let packID = AppDeepLink.packID(for: url) else { return }
            selectedPack = packID
            Analytics.send("DeepLink.opened", with: [
                "url": url.absoluteString,
                "pack": packID
            ])
        }
    }
}
