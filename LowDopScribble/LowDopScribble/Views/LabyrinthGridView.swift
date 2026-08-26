import SwiftUI

struct LabyrinthGridView: View {
    @EnvironmentObject var gameViewModel: GameViewModel
    @EnvironmentObject var progressTracker: ProgressTracker

    var packId: String = "letters"
    var onBackToBookshelf: (() -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        Group {
            if packId == "letters", let onBackToBookshelf {
                LetterGridView(onBackToBookshelf: onBackToBookshelf)
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            HStack {
                                if let goBack = onBackToBookshelf {
                                    Button(action: goBack) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 14, weight: .semibold))
                                            Image(systemName: "books.vertical")
                                                .font(.system(size: 16, weight: .medium))
                                        }
                                        .foregroundColor(AppColor.textSecondary)
                                        .padding(8)
                                        .background(AppColor.textPrimary.opacity(0.08))
                                        .cornerRadius(10)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your Exercises")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColor.textPrimary)
                                        .accessibilityIdentifier("grid.title")
                                    Text("\(progressTracker.completedCount(in: gameViewModel.labyrinths)) of \(gameViewModel.labyrinths.count) completed")
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundColor(AppColor.textTertiary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppColor.accentGreen)
                                        .frame(width: progressFraction * geo.size.width, height: 8)
                                }
                            }
                            .frame(height: 8)
                            .padding(.horizontal, 20)

                            if let location = gameViewModel.labyrinths.first?.location {
                                Text(location.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppColor.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                            }

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(Array(gameViewModel.labyrinths.enumerated()), id: \.element.id) { index, labyrinth in
                                    LabyrinthCard(
                                        labyrinth: labyrinth,
                                        index: index + 1,
                                        isCompleted: progressTracker.isCompleted(labyrinth.id),
                                        isLocked: false
                                    )
                                    .onTapGesture {
                                        Analytics.send("Grid.labyrinthTapped", with: [
                                            "labyrinthId": labyrinth.id,
                                            "index": String(index)
                                        ])
                                        gameViewModel.selectLabyrinth(labyrinth)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                    }
                    .background(AppColor.background)
                    .toolbar(.hidden, for: .navigationBar)
                }
                .onAppear {
                    gameViewModel.loadLabyrinths(packId: packId)
                    Analytics.send("Grid.opened", with: [
                        "pack": packId,
                        "completedCount": String(progressTracker.completedCount(in: gameViewModel.labyrinths)),
                        "totalCount": String(gameViewModel.labyrinths.count)
                    ])
                }
                .fullScreenCover(isPresented: $gameViewModel.isPlaying) {
                    LabyrinthListView()
                }
            }
        }
    }

    private var progressFraction: CGFloat {
        guard !gameViewModel.labyrinths.isEmpty else { return 0 }
        return CGFloat(progressTracker.completedCount(in: gameViewModel.labyrinths)) / CGFloat(gameViewModel.labyrinths.count)
    }
}

struct LabyrinthCard: View {
    let labyrinth: Labyrinth
    let index: Int
    let isCompleted: Bool
    var isLocked: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                GeometryReader { geo in
                    let thumbSize = min(geo.size.width, geo.size.height)
                    let charScale = thumbSize * 0.5 / 80
                    Color.clear
                    ZStack {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        } else {
                            CharacterMarkerView(
                                character: labyrinth.characterEnd,
                                scale: charScale,
                                isStart: false
                            )
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: labyrinth.visualTheme.backgroundColor) ?? .blue)
                )
                .aspectRatio(1.1, contentMode: .fit)
                .frame(minHeight: 80)

                if isCompleted {
                    VStack {
                        HStack {
                            Spacer()
                            StarShape(points: 5, innerRatio: 0.45)
                                .fill(AppColor.accentYellow)
                                .frame(width: 24, height: 24)
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                                .padding(6)
                        }
                        Spacer()
                    }
                }

                if let emoji = labyrinth.itemEmoji {
                    let badgeText = labyrinth.itemRule == "avoid" ? "🚫 \(emoji)" : emoji
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(badgeText)
                                .font(.system(size: 16))
                                .padding(4)
                                .background(Color.white.opacity(0.85))
                                .cornerRadius(8)
                                .padding(6)
                        }
                    }
                }
            }
            .opacity(isLocked ? 0.5 : 1.0)

            Text("\(index). \(labyrinth.title)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 36, alignment: .top)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}
