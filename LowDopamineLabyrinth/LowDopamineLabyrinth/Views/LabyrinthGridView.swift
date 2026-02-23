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
    @State private var paywallSkipped = false
    @State private var pendingLabyrinth: Labyrinth? = nil
    @State private var parentalGateAction: ParentalGateAction = .privacyPolicy

    private enum ParentalGateAction {
        case privacyPolicy
        case difficultyPicker
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
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
                            .background(Color(hex: "#6BBF7B") ?? .green)
                            .cornerRadius(12)
                        }
                        // For Parents button
                        Button(action: {
                            parentalGateAction = .privacyPolicy
                            showParentalGate = true
                        }) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#5D4E37")?.opacity(0.5) ?? .gray)
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
                                .fill(Color(hex: "#6BBF7B") ?? .green)
                                .frame(width: progressFraction * geo.size.width, height: 8)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 20)

                    // Location header
                    if let location = gameViewModel.labyrinths.first?.location {
                        Text(location.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#5D4E37")?.opacity(0.7) ?? .brown)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                    }

                    // "Come back tomorrow" banner for free users who used their daily play
                    if !gameViewModel.canProceed() {
                        HStack(spacing: 12) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "#5BA8D9") ?? .blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("See you tomorrow!")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                                Text("Your free labyrinth for today is done. Come back tomorrow for a new one!")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.7))
                            }
                            Spacer()
                            Button(action: { showPaywall = true }) {
                                Text("Unlock All")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "#5BA8D9") ?? .blue)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(16)
                        .background(Color(hex: "#5BA8D9")?.opacity(0.1) ?? .blue.opacity(0.1))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    }

                    // Grid — 4 columns for landscape
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(gameViewModel.labyrinths.enumerated()), id: \.element.id) { index, labyrinth in
                            let isUnlocked = index == 0 || progressTracker.isCompleted(gameViewModel.labyrinths[index - 1].id)
                            LabyrinthCard(
                                labyrinth: labyrinth,
                                index: index + 1,
                                isCompleted: progressTracker.isCompleted(labyrinth.id),
                                isLocked: !isUnlocked
                            )
                            .onTapGesture {
                                if isUnlocked {
                                    if gameViewModel.canProceed() {
                                        gameViewModel.selectLabyrinth(labyrinth)
                                    } else {
                                        pendingLabyrinth = labyrinth
                                        showPaywall = true
                                    }
                                }
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
        .sheet(isPresented: $showDifficultyPicker) {
            DifficultyPickerSheet(onSelect: { newLevel in
                preferences.difficultyLevel = newLevel
                gameViewModel.loadLabyrinths()
                showDifficultyPicker = false
            })
        }
        .fullScreenCover(isPresented: $showParentalGate) {
            ParentalGateView(
                onSuccess: {
                    showParentalGate = false
                    switch parentalGateAction {
                    case .privacyPolicy:
                        showPrivacyPolicy = true
                    case .difficultyPicker:
                        showDifficultyPicker = true
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
            if let lab = pendingLabyrinth, (gameViewModel.isPremium || paywallSkipped) {
                paywallSkipped = false
                pendingLabyrinth = nil
                gameViewModel.selectLabyrinth(lab)
            } else {
                pendingLabyrinth = nil
            }
        }) {
            PaywallView(onSkip: { paywallSkipped = true })
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
                    let bounds = labyrinth.contentBounds
                    let scaleX = geo.size.width / bounds.width
                    let scaleY = geo.size.height / bounds.height
                    let mazeScale = min(scaleX, scaleY) * 0.85
                    let mazeOffset = CGPoint(
                        x: geo.size.width / 2 - bounds.midX * mazeScale,
                        y: geo.size.height / 2 - bounds.midY * mazeScale
                    )
                    let isCorridor = labyrinth.pathData.mazeType.hasPrefix("corridor") || labyrinth.pathData.mazeType == "organic"
                    let lineWidth = isCorridor
                        ? CGFloat(labyrinth.pathData.width) * mazeScale
                        : max(1.5, 2 * mazeScale)

                    Color.clear

                    if isLocked {
                        // Faded maze + lock icon
                        SVGPathParser.parse(labyrinth.pathData.svgPath, scale: mazeScale, offset: mazeOffset)
                            .stroke(Color.white.opacity(0.2), style: StrokeStyle(
                                lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        // Maze path
                        SVGPathParser.parse(labyrinth.pathData.svgPath, scale: mazeScale, offset: mazeOffset)
                            .stroke(Color.white.opacity(0.7), style: StrokeStyle(
                                lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                        // Small character at end point
                        let endPos = CGPoint(
                            x: CGFloat(labyrinth.pathData.endPoint.x) * mazeScale + mazeOffset.x,
                            y: CGFloat(labyrinth.pathData.endPoint.y) * mazeScale + mazeOffset.y
                        )
                        let charScale = min(geo.size.width, geo.size.height) * 0.3 / 80
                        CharacterMarkerView(
                            character: labyrinth.characterEnd,
                            scale: charScale,
                            isStart: false
                        )
                        .position(endPos)
                    }
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
                                .fill(Color(hex: "#F1C40F") ?? .yellow)
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
                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
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

    var body: some View {
        VStack(spacing: 24) {
            Text("Change Difficulty")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                .padding(.top, 24)

            HStack(spacing: 16) {
                ForEach(DifficultyLevel.allCases, id: \.self) { level in
                    Button(action: { onSelect(level) }) {
                        VStack(spacing: 8) {
                            Text(level.displayName)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
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
