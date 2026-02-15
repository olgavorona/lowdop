import SwiftUI

struct LabyrinthGridView: View {
    @EnvironmentObject var gameViewModel: GameViewModel
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var progressTracker: ProgressTracker
    @State private var showAgeSelector = false

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Progress header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Labyrinths")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                            Text("\(progressTracker.completedCount(in: gameViewModel.labyrinths)) of \(gameViewModel.labyrinths.count) completed")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        // Age badge — tappable to change
                        Button(action: { showAgeSelector = true }) {
                            HStack(spacing: 4) {
                                Text(preferences.ageGroup.displayName + " yrs")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#6BBF7B") ?? .green)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "#6BBF7B") ?? .green)
                                .frame(width: progressFraction * geo.size.width, height: 8)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 20)

                    // Grid — 2 columns for young kids
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(Array(gameViewModel.labyrinths.enumerated()), id: \.element.id) { index, labyrinth in
                            LabyrinthCard(
                                labyrinth: labyrinth,
                                index: index + 1,
                                isCompleted: progressTracker.isCompleted(labyrinth.id)
                            )
                            .onTapGesture {
                                gameViewModel.selectLabyrinth(labyrinth)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(hex: "#FFF8E7") ?? Color(.systemBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            gameViewModel.loadLabyrinths()
        }
        .fullScreenCover(isPresented: $gameViewModel.isPlaying) {
            LabyrinthListView()
        }
        .sheet(isPresented: $gameViewModel.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showAgeSelector) {
            AgePickerSheet(onSelect: { newAge in
                preferences.ageGroup = newAge
                gameViewModel.loadLabyrinths()
                showAgeSelector = false
            })
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

    var body: some View {
        VStack(spacing: 10) {
            // Colored maze thumbnail area
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: labyrinth.visualTheme.backgroundColor) ?? .blue)
                    .frame(minHeight: 100)
                    .aspectRatio(1.1, contentMode: .fit)

                if isCompleted {
                    // Show gold star badge for completed
                    StarShape(points: 5, innerRatio: 0.45)
                        .fill(Color(hex: "#F1C40F") ?? .yellow)
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                } else if let endName = labyrinth.characterEnd.name {
                    // Show end character info for Denny universe
                    VStack(spacing: 4) {
                        CharacterMarkerView(
                            character: labyrinth.characterEnd,
                            scale: 1.5,
                            isStart: false
                        )
                        Text(endName)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                } else {
                    // Fallback: index number
                    Text("\(index)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            // Title
            Text(labyrinth.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let location = labyrinth.location {
                Text(location.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }

            // Difficulty dots
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < difficultyLevel ? difficultyColor : Color.gray.opacity(0.2))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    private var difficultyLevel: Int {
        switch labyrinth.difficulty {
        case "easy": return 1
        case "medium": return 2
        case "hard": return 3
        default: return 1
        }
    }

    private var difficultyColor: Color {
        switch labyrinth.difficulty {
        case "easy": return Color(hex: "#6BBF7B") ?? .green
        case "medium": return Color(hex: "#5BA8D9") ?? .blue
        case "hard": return Color(hex: "#E67E22") ?? .orange
        default: return .gray
        }
    }
}

struct AgePickerSheet: View {
    let onSelect: (AgeGroup) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Change Age Group")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                .padding(.top, 24)

            HStack(spacing: 16) {
                ForEach(AgeGroup.allCases, id: \.self) { group in
                    Button(action: { onSelect(group) }) {
                        VStack(spacing: 8) {
                            Text(group == .young ? "🐣" : "⭐")
                                .font(.system(size: 36))
                            Text(group.displayName)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("years")
                                .font(.system(size: 14, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(hex: "#6BBF7B")?.opacity(0.15) ?? .green.opacity(0.15))
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 24)

            Button("Cancel") { dismiss() }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
        }
    }
}
