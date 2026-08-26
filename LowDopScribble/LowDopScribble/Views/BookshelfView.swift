import SwiftUI

struct BookshelfView: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var progressTracker: ProgressTracker

    let onPackSelected: (String) -> Void

    @State private var storiesByPack: [String: [StoryInfo]] = [:]

    // MARK: - Book Configuration

    private struct BookConfig: Identifiable {
        let id: String
        let title: String
        let gradientColors: [Color]
        let progressBarColor: Color
        let icon: BookIcon
        let decoration: BookDecoration

        enum BookIcon {
            case system(String, Color)
            case emoji(String)
        }

        enum BookDecoration {
            case waves
            case stars
            case leaves
        }
    }

    private static let books: [BookConfig] = [
        BookConfig(
            id: "letters",
            title: "Letters",
            gradientColors: [Color(hex: "#4FC3F7") ?? .blue, AppColor.linkBlue, Color(hex: "#01579B") ?? .blue],
            progressBarColor: Color(hex: "#4FC3F7") ?? .blue,
            icon: .system("textformat.abc", .white.opacity(0.9)),
            decoration: .waves
        ),
        BookConfig(
            id: "numbers",
            title: "Numbers",
            gradientColors: [Color(hex: "#1A1A2E") ?? .black, Color(hex: "#16213E") ?? .indigo, Color(hex: "#0F3460") ?? .blue],
            progressBarColor: Color(hex: "#0F3460") ?? .blue,
            icon: .system("number", .yellow.opacity(0.9)),
            decoration: .stars
        ),
        BookConfig(
            id: "shapes",
            title: "Symbols",
            gradientColors: [Color(hex: "#1A3D1A") ?? .green, Color(hex: "#2D5A27") ?? .green, Color(hex: "#4A7C3F") ?? .green],
            progressBarColor: Color(hex: "#2D5A27") ?? .green,
            icon: .system("plus.forwardslash.minus", .white.opacity(0.9)),
            decoration: .leaves
        ),
    ]

    var body: some View {
        ZStack {
            AppColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Denny's ABC Tracing")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                    .accessibilityIdentifier("bookshelf.title")

                bookCardsArea
                Spacer()
            }
        }
        .onAppear {
            for config in Self.books {
                storiesByPack[config.id] = LabyrinthLoader.shared.loadStories(packId: config.id)
            }
        }
    }

    // MARK: - Book Cards Area

    private var bookCardsArea: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(Self.books) { config in
                    bookCard(config: config, stories: storiesByPack[config.id] ?? [])
                }
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Book Card

    private func bookCard(config: BookConfig, stories: [StoryInfo]) -> some View {
        let completedCount = progressTracker.completedStoryCount(in: stories)
        let totalCount = config.id == "letters" ? 26 : stories.count

        return Button(action: {
            Analytics.send("Bookshelf.bookTapped", with: ["pack": config.id])
            onPackSelected(config.id)
        }) {
            VStack(spacing: 0) {
                bookCover(config: config, totalCount: totalCount)
                    .frame(height: 200)
                bookBottom(config: config, completedCount: completedCount, totalCount: totalCount)
            }
            .frame(width: 280)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func bookCover(config: BookConfig, totalCount: Int) -> some View {
        ZStack {
            LinearGradient(colors: config.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)

            bookDecoration(config.decoration)

            VStack(spacing: 8) {
                bookIconView(config.icon)
                Text(config.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if totalCount > 0 {
                    Text("\(totalCount) exercises")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("Coming soon")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    private func bookBottom(config: BookConfig, completedCount: Int, totalCount: Int) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(totalCount > 0
                    ? "\(completedCount) of \(totalCount) completed"
                    : "Tap to explore")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppColor.textSecondary)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(config.progressBarColor)
                        .frame(
                            width: totalCount > 0
                                ? CGFloat(completedCount) / CGFloat(totalCount) * geo.size.width
                                : 0,
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            HStack {
                Spacer()
                Text("Tap to play")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.linkBlue)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColor.linkBlue)
            }
        }
        .padding(16)
        .background(Color.white)
    }

    @ViewBuilder
    private func bookDecoration(_ decoration: BookConfig.BookDecoration) -> some View {
        switch decoration {
        case .waves:
            VStack {
                Spacer()
                WaveShape()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 60)
                WaveShape()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 40)
                    .offset(y: -20)
            }
        case .stars:
            ForEach(0..<12, id: \.self) { i in
                let xPos = CGFloat((i * 23 + 15) % 260) + 10
                let yPos = CGFloat((i * 17 + 20) % 160) + 10
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: i % 3 == 0 ? 4 : 2)
                    .position(x: xPos, y: yPos)
            }
        case .leaves:
            ForEach(0..<10, id: \.self) { i in
                let xPos = CGFloat((i * 27 + 10) % 260) + 10
                let yPos = CGFloat((i * 19 + 15) % 160) + 10
                Text(i % 2 == 0 ? "🍃" : "🌿")
                    .font(.system(size: i % 3 == 0 ? 18 : 12))
                    .opacity(0.4)
                    .position(x: xPos, y: yPos)
            }
        }
    }

    @ViewBuilder
    private func bookIconView(_ icon: BookConfig.BookIcon) -> some View {
        switch icon {
        case .system(let name, let color):
            Image(systemName: name)
                .font(.system(size: 40))
                .foregroundColor(color)
        case .emoji(let char):
            Text(char)
                .font(.system(size: 40))
        }
    }
}

// MARK: - Wave Shape

private struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height * 0.5))
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.3),
            control1: CGPoint(x: width * 0.15, y: 0),
            control2: CGPoint(x: width * 0.35, y: height * 0.6)
        )
        path.addCurve(
            to: CGPoint(x: width, y: height * 0.4),
            control1: CGPoint(x: width * 0.65, y: 0),
            control2: CGPoint(x: width * 0.85, y: height * 0.7)
        )
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}
