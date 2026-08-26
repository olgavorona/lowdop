import SwiftUI

extension Notification.Name {
    static let returnToBookshelf = Notification.Name("returnToBookshelf")
}

struct ContentView: View {
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
            if let packId = selectedPack {
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
    }
}
