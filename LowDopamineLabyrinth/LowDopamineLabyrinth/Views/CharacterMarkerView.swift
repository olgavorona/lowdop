import SwiftUI

/// Displays a character marker on the maze - either an image from the asset catalog
/// or a fallback emoji/geometric shape.
struct CharacterMarkerView: View {
    let character: LabyrinthCharacter
    let scale: CGFloat
    let isStart: Bool

    @State private var isPulsing = false

    private var markerSize: CGFloat {
        (isStart ? 32 : 28) * scale
    }

    var body: some View {
        VStack(spacing: 2 * scale) {
            Group {
                if let imageAsset = character.imageAsset,
                   UIImage(named: imageAsset) != nil {
                    Image(imageAsset)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: markerSize, height: markerSize)
                        .clipShape(Circle())
                        .overlay(markerBorder)
                        .shadow(color: .black.opacity(0.2), radius: 3 * scale, y: 1 * scale)
                } else {
                    fallbackMarker
                }
            }
            .scaleEffect((!isStart && isPulsing) ? 1.15 : 1.0)
            .animation(
                !isStart
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )

            // Label below marker
            if isStart {
                Text("GO")
                    .font(.system(size: max(9, 10 * scale), weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4 * scale)
                    .padding(.vertical, 1 * scale)
                    .background(Color(hex: "#27AE60") ?? .green)
                    .cornerRadius(4 * scale)
            } else if let name = character.name {
                Text(name)
                    .font(.system(size: max(8, 9 * scale), weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3 * scale)
                    .padding(.vertical, 1 * scale)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(3 * scale)
            }
        }
        .onAppear {
            if !isStart {
                isPulsing = true
            }
        }
    }

    @ViewBuilder
    private var markerBorder: some View {
        if isStart {
            Circle()
                .strokeBorder(Color(hex: "#27AE60") ?? .green, lineWidth: 2 * scale)
        } else {
            Circle()
                .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 2 * scale, dash: [4 * scale, 3 * scale]))
        }
    }

    @ViewBuilder
    private var fallbackMarker: some View {
        let emoji = characterEmoji
        if !emoji.isEmpty {
            ZStack {
                Circle()
                    .fill(characterColor)
                    .frame(width: markerSize, height: markerSize)
                    .shadow(color: .black.opacity(0.15), radius: 2 * scale)
                    .overlay(markerBorder)
                Text(emoji)
                    .font(.system(size: markerSize * 0.55))
            }
        } else if isStart {
            ZStack {
                Circle()
                    .fill(Color(hex: "#E74C3C") ?? .red)
                    .frame(width: 28 * scale, height: 28 * scale)
                    .overlay(
                        Circle()
                            .strokeBorder(Color(hex: "#27AE60") ?? .green, lineWidth: 2 * scale)
                    )
                Triangle()
                    .fill(Color.white)
                    .frame(width: 12 * scale, height: 12 * scale)
            }
        } else {
            StarShape(points: 5, innerRatio: 0.45)
                .fill(Color(hex: "#F1C40F") ?? .yellow)
                .frame(width: 24 * scale, height: 24 * scale)
        }
    }

    private var characterEmoji: String {
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
        let colorMap: [String: String] = [
            "denny": "#E74C3C",
            "mama_coral": "#F1948A",
            "papa_reef": "#922B21",
            "sandy": "#F4D03F",
            "finn": "#E67E22",
            "stella": "#8E44AD",
            "ollie": "#5B2C6F",
            "shelly": "#27AE60",
            "bubbles": "#F1C40F",
            "pearl": "#D5A6BD",
        ]
        if let asset = character.imageAsset,
           let hex = colorMap[asset] {
            return Color(hex: hex) ?? (isStart ? .red : .yellow)
        }
        return isStart ? Color(hex: "#E74C3C") ?? .red : Color(hex: "#F1C40F") ?? .yellow
    }
}
