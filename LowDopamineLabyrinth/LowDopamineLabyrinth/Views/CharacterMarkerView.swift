import SwiftUI

/// Displays a character marker on the maze - either an image from the asset catalog
/// or a fallback emoji/geometric shape.
struct CharacterMarkerView: View {
    let character: LabyrinthCharacter
    let scale: CGFloat
    let isStart: Bool

    private var markerSize: CGFloat {
        (isStart ? 32 : 28) * scale
    }

    var body: some View {
        Group {
            if let imageAsset = character.imageAsset,
               UIImage(named: imageAsset) != nil {
                // Character image from asset catalog
                Image(imageAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: markerSize, height: markerSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2 * scale)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3 * scale, y: 1 * scale)
            } else {
                // Fallback: emoji or geometric shape
                fallbackMarker
            }
        }
    }

    @ViewBuilder
    private var fallbackMarker: some View {
        let emoji = characterEmoji
        if !emoji.isEmpty {
            // Emoji fallback
            ZStack {
                Circle()
                    .fill(characterColor)
                    .frame(width: markerSize, height: markerSize)
                    .shadow(color: .black.opacity(0.15), radius: 2 * scale)
                Text(emoji)
                    .font(.system(size: markerSize * 0.55))
            }
        } else if isStart {
            // Original start marker (red circle + arrow)
            ZStack {
                Circle()
                    .fill(Color(hex: "#E74C3C") ?? .red)
                    .frame(width: 28 * scale, height: 28 * scale)
                Triangle()
                    .fill(Color.white)
                    .frame(width: 12 * scale, height: 12 * scale)
            }
        } else {
            // Original end marker (gold star)
            StarShape(points: 5, innerRatio: 0.45)
                .fill(Color(hex: "#F1C40F") ?? .yellow)
                .frame(width: 24 * scale, height: 24 * scale)
        }
    }

    private var characterEmoji: String {
        // Map character image_asset keys to emoji
        let emojiMap: [String: String] = [
            "denny": "\u{1F980}",
            "mama_coral": "\u{1F980}",
            "papa_reef": "\u{1F980}",
            "sandy": "\u{1F980}",
            "finn": "\u{1F420}",
            "stella": "\u{2B50}",
            "ollie": "\u{1F419}",
            "shelly": "\u{1F422}",
            "bubbles": "\u{1FAE7}",
            "pearl": "\u{1FABC}",
        ]
        if let asset = character.imageAsset {
            return emojiMap[asset] ?? ""
        }
        return ""
    }

    private var characterColor: Color {
        // Character-specific background colors from the universe bible
        let colorMap: [String: String] = [
            "denny": "#E74C3C",       // orange-red
            "mama_coral": "#F1948A",   // coral-pink
            "papa_reef": "#922B21",    // deep red-brown
            "sandy": "#F4D03F",        // sandy-yellow
            "finn": "#E67E22",         // orange
            "stella": "#8E44AD",       // purple-pink
            "ollie": "#5B2C6F",        // blue-purple
            "shelly": "#27AE60",       // green
            "bubbles": "#F1C40F",      // golden-yellow
            "pearl": "#D5A6BD",        // pink-white
        ]
        if let asset = character.imageAsset,
           let hex = colorMap[asset] {
            return Color(hex: hex) ?? (isStart ? .red : .yellow)
        }
        return isStart ? Color(hex: "#E74C3C") ?? .red : Color(hex: "#F1C40F") ?? .yellow
    }
}
