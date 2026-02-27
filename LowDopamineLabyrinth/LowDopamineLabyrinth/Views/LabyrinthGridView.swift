import SwiftUI

struct LabyrinthGridView: View {
    @EnvironmentObject var gameViewModel: GameViewModel
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var progressTracker: ProgressTracker
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showDifficultyPicker = false
    @State private var showParentalGate = false
    @State private var showPrivacyPolicy = false
    @State private var showPaywall = false
    @State private var pendingLabyrinth: Labyrinth? = nil
    @State private var parentalGateAction: ParentalGateAction = .privacyPolicy

    /// Optional callback to navigate back to the bookshelf.
    /// When provided, a back button is shown in the header.
    var onBackToBookshelf: (() -> Void)? = nil

    private enum ParentalGateAction {
        case privacyPolicy
        case difficultyPicker
        case paywall
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Progress header
                    HStack {
                        // Back to bookshelf button
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
                            Text("Your Labyrinths")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(AppColor.textPrimary)
                            Text("\(progressTracker.completedCount(in: gameViewModel.labyrinths)) of \(gameViewModel.labyrinths.count) completed")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(AppColor.textTertiary)
                        }
                        Spacer()
                        // Difficulty badge — tappable to change (behind parental gate)
                        Button(action: {
                            parentalGateAction = .difficultyPicker
                            showParentalGate = true
                        }) {
                            HStack(spacing: 4) {
                                Text(preferences.difficultyLevel.displayName)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColor.accentGreen)
                            .cornerRadius(12)
                        }
                        // For Parents button
                        Button(action: {
                            parentalGateAction = .privacyPolicy
                            showParentalGate = true
                        }) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColor.textPrimary.opacity(0.5))
                                .frame(width: 32, height: 32)
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
                                .fill(AppColor.accentGreen)
                                .frame(width: progressFraction * geo.size.width, height: 8)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 20)

                    // Location header
                    if let location = gameViewModel.labyrinths.first?.location {
                        Text(location.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                    }

                    // Grid — 4 columns for landscape
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(gameViewModel.labyrinths.enumerated()), id: \.element.id) { index, labyrinth in
                            let isLocked = index >= 3 && !gameViewModel.isPremium
                            LabyrinthCard(
                                labyrinth: labyrinth,
                                index: index + 1,
                                isCompleted: progressTracker.isCompleted(labyrinth.id),
                                isLocked: isLocked
                            )
                            .onTapGesture {
                                Analytics.send("Grid.labyrinthTapped", with: [
                                    "labyrinthId": labyrinth.id,
                                    "index": String(index),
                                    "isLocked": String(isLocked)
                                ])
                                if isLocked {
                                    pendingLabyrinth = labyrinth
                                    parentalGateAction = .paywall
                                    showParentalGate = true
                                    Analytics.send("Paywall.shown", with: ["trigger": "grid"])
                                } else {
                                    gameViewModel.selectLabyrinth(labyrinth)
                                }
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
            gameViewModel.loadLabyrinths()
            Analytics.send("Grid.opened", with: [
                "difficulty": preferences.difficultyLevel.rawValue,
                "completedCount": String(progressTracker.completedCount(in: gameViewModel.labyrinths)),
                "totalCount": String(gameViewModel.labyrinths.count)
            ])
        }
        .fullScreenCover(isPresented: $gameViewModel.isPlaying) {
            LabyrinthListView()
        }
        .sheet(isPresented: $showDifficultyPicker) {
            DifficultyPickerSheet(onSelect: { newLevel in
                let oldLevel = preferences.difficultyLevel
                preferences.difficultyLevel = newLevel
                gameViewModel.loadLabyrinths()
                showDifficultyPicker = false
                Analytics.send("Grid.difficultyChanged", with: ["from": oldLevel.rawValue, "to": newLevel.rawValue])
            })
        }
        .fullScreenCover(isPresented: $showParentalGate) {
            ParentalGateView(
                purpose: parentalGatePurpose,
                onSuccess: {
                    showParentalGate = false
                    switch parentalGateAction {
                    case .privacyPolicy:
                        showPrivacyPolicy = true
                    case .difficultyPicker:
                        showDifficultyPicker = true
                    case .paywall:
                        showPaywall = true
                    }
                },
                onCancel: {
                    showParentalGate = false
                }
            )
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            if let lab = pendingLabyrinth, gameViewModel.isPremium {
                pendingLabyrinth = nil
                gameViewModel.selectLabyrinth(lab)
            } else {
                pendingLabyrinth = nil
            }
        }) {
            PaywallView()
        }
    }

    private var parentalGatePurpose: ParentalGateView.Purpose {
        switch parentalGateAction {
        case .privacyPolicy: return .privacyPolicy
        case .difficultyPicker: return .settings
        case .paywall: return .paywall
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
            // Colored maze thumbnail area
            ZStack {
                GeometryReader { geo in
                    let thumbSize = min(geo.size.width, geo.size.height)
                    let charScale = thumbSize * 0.5 / 80 // 50% of square, end marker = 80*scale
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

                // Completion star badge (top-right corner)
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

                // Item emoji badge (bottom-right corner) for adventure mazes
                if let emoji = labyrinth.itemEmoji {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(emoji)
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

            // Title with level number — fixed height for uniform cards
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

struct DifficultyPickerSheet: View {
    let onSelect: (DifficultyLevel) -> Void
    @Environment(\.dismiss) var dismiss

    private let levelColors: [DifficultyLevel: [Color]] = [
        .easy: [Color(hex: "#4FC3F7") ?? .blue, Color(hex: "#29B6F6") ?? .blue],
        .medium: [Color(hex: "#29B6F6") ?? .blue, Color(hex: "#039BE5") ?? .blue],
        .hard: [Color(hex: "#039BE5") ?? .blue, Color(hex: "#0277BD") ?? .blue],
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Change Difficulty")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.top, 20)

            HStack(spacing: 12) {
                ForEach(DifficultyLevel.allCases, id: \.self) { level in
                    DifficultyCard(
                        level: level,
                        colors: levelColors[level] ?? [.blue, .blue],
                        samplePath: loadSamplePath(for: level)
                    ) {
                        onSelect(level)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button("Cancel") { dismiss() }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(AppColor.textTertiary)
                .padding(.bottom, 16)
        }
        .padding()
        .background(AppColor.background)
    }

    private func loadSamplePath(for level: DifficultyLevel) -> String {
        guard let url = Bundle.main.url(forResource: "difficulty_samples", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let samples = try? JSONDecoder().decode([String: String].self, from: data) else {
            return ""
        }
        return samples[level.rawValue] ?? ""
    }
}
