import SwiftUI

/// Displays a character marker on the maze - either an image from the asset catalog
/// or a fallback emoji/geometric shape.
struct CharacterMarkerView: View {
    let character: LabyrinthCharacter
    let scale: CGFloat
    let isStart: Bool
    var clipToCircle: Bool = true

    private var markerSize: CGFloat {
        (isStart ? 32 : 80) * scale
    }

    var body: some View {
        VStack(spacing: 2 * scale) {
            Group {
                if let imageAsset = character.imageAsset,
                   UIImage(named: imageAsset) != nil {
                    if clipToCircle {
                        Image(imageAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: markerSize, height: markerSize)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        isStart ? (AppColor.endMarkerGreen) : Color.white,
                                        lineWidth: 2 * scale
                                    )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 3 * scale, y: 1 * scale)
                    } else {
                        Image(imageAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: markerSize, height: markerSize)
                            .shadow(color: .black.opacity(0.3), radius: 4 * scale, y: 2 * scale)
                    }
                } else {
                    fallbackMarker
                }
            }

            // Label below marker
            if isStart {
                Text("GO")
                    .font(.system(size: max(9, 10 * scale), weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4 * scale)
                    .padding(.vertical, 1 * scale)
                    .background(AppColor.endMarkerGreen)
                    .cornerRadius(4 * scale)
            } else if let name = character.name {
                Text(name)
                    .font(.system(size: max(10, 13 * scale), weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4 * scale)
                    .padding(.vertical, 2 * scale)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4 * scale)
            }
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
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isStart ? (AppColor.endMarkerGreen) : Color.white,
                                lineWidth: 2 * scale
                            )
                    )
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
                            .strokeBorder(AppColor.endMarkerGreen, lineWidth: 2 * scale)
                    )
                Triangle()
                    .fill(Color.white)
                    .frame(width: 12 * scale, height: 12 * scale)
            }
        } else {
            StarShape(points: 5, innerRatio: 0.45)
                .fill(Color(hex: "#F1C40F") ?? .yellow)
                .frame(width: 40 * scale, height: 40 * scale)
        }
    }

    private var characterEmoji: String {
        let emojiMap: [String: String] = [
            "denny": "\u{1F980}",
            "denny_forest": "\u{1F980}",
            "maya_forest": "\u{1F42D}",
            "mama_coral": "\u{1F980}",
            "daddy_reef": "\u{1F980}",
            "sandy": "\u{1F980}",
            "finn": "\u{1F420}",
            "stella": "\u{2B50}",
            "ollie": "\u{1F419}",
            "shelly": "\u{1F422}",
            "bubbles": "\u{1FAE7}",
            "pearl": "\u{1FABC}",
            "robin_forest": "\u{1F426}",
            "squirrel_forest": "\u{1F43F}",
            "rabbit_forest": "\u{1F407}",
            "hedgehog_forest": "\u{1F994}",
            "fox_forest": "\u{1F98A}",
            "bear_forest": "\u{1F43B}",
            "deer_forest": "\u{1F98C}",
            "butterfly_forest": "\u{1F98B}",
            "bee_forest": "\u{1F41D}",
            "chipmunk_forest": "\u{1F43F}",
            "snail_forest": "\u{1F40C}",
            "ladybug_forest": "\u{1F41E}",
            "turtle_forest": "\u{1F422}",
            "raccoon_forest": "\u{1F99D}",
            "badger_forest": "\u{1F9A1}",
            "frog_forest": "\u{1F438}",
            "beaver_forest": "\u{1F9AB}",
            "caterpillar_forest": "\u{1F41B}",
            "firefly_forest": "\u{2728}",
            "wolf_forest": "\u{1F43A}",
        ]
        if let asset = character.imageAsset {
            return emojiMap[asset] ?? ""
        }
        return ""
    }

    private var characterColor: Color {
        let colorMap: [String: String] = [
            "denny": "#E74C3C",
            "denny_forest": "#E74C3C",
            "maya_forest": "#8B4513",
            "mama_coral": "#F1948A",
            "daddy_reef": "#922B21",
            "sandy": "#F4D03F",
            "finn": "#E67E22",
            "stella": "#8E44AD",
            "ollie": "#5B2C6F",
            "shelly": "#27AE60",
            "bubbles": "#F1C40F",
            "pearl": "#D5A6BD",
            "robin_forest": "#C0392B",
            "squirrel_forest": "#A65E2E",
            "rabbit_forest": "#D7DDE5",
            "hedgehog_forest": "#8B5E3C",
            "fox_forest": "#D35400",
            "bear_forest": "#6E4B3A",
            "deer_forest": "#B07D52",
            "butterfly_forest": "#E67E22",
            "bee_forest": "#F1C40F",
            "chipmunk_forest": "#B97745",
            "snail_forest": "#6D4C41",
            "ladybug_forest": "#C62828",
            "turtle_forest": "#2E8B57",
            "raccoon_forest": "#616A6B",
            "badger_forest": "#424949",
            "frog_forest": "#27AE60",
            "beaver_forest": "#8D6E63",
            "caterpillar_forest": "#7CB342",
            "firefly_forest": "#F4D03F",
            "wolf_forest": "#7F8C8D",
        ]
        if let asset = character.imageAsset,
           let hex = colorMap[asset] {
            return Color(hex: hex) ?? (isStart ? .red : .yellow)
        }
        return isStart ? Color(hex: "#E74C3C") ?? .red : Color(hex: "#F1C40F") ?? .yellow
    }
}
