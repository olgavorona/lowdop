import SwiftUI

struct LabyrinthGridView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject var gameViewModel: GameViewModel
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var progressTracker: ProgressTracker
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showDifficultyPicker = false
    @State private var showParentalGate = false
    @State private var showAccount = false
    @State private var showPaywall = false
    @State private var pendingLabyrinth: Labyrinth? = nil
    @State private var parentalGateAction: ParentalGateAction = .account
    @State private var didAutoOpenUITestLabyrinth = false

    var packId: String = "ocean_adventures"

    /// Optional callback to navigate back to the bookshelf.
    /// When provided, a back button is shown in the header.
    var onBackToBookshelf: (() -> Void)? = nil

    private enum ParentalGateAction {
        case account
        case difficultyPicker
        case paywall
    }

    private var columns: [GridItem] {
        let isPortraitPhone = UIDevice.current.userInterfaceIdiom == .phone
            && verticalSizeClass != .compact
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: isPortraitPhone ? 2 : 4)
    }

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
                                .accessibilityIdentifier("grid.title")
                            Text(AppLocalization.text(
                                #"\(progressTracker.completedCount(in: gameViewModel.labyrinths)) of \(gameViewModel.labyrinths.count) completed"#,
                                replacing: [
                                    #"\(progressTracker.completedCount(in: gameViewModel.labyrinths))"#: String(progressTracker.completedCount(in: gameViewModel.labyrinths)),
                                    #"\(gameViewModel.labyrinths.count)"#: String(gameViewModel.labyrinths.count)
                                ]
                            ))
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(AppColor.textTertiary)
                        }
                        Spacer()
                        // Difficulty badge — tappable to change (behind parental gate)
                        if !gameViewModel.currentPackUsesFixedDifficulty {
                        Button(action: {
                            parentalGateAction = .difficultyPicker
                            showParentalGate = true
                        }) {
                            HStack(spacing: 4) {
                                Text(LocalizedStringKey(preferences.difficultyLevel.displayName))
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
                        }
                        // For Parents button
                        Button(action: {
                            parentalGateAction = .account
                            showParentalGate = true
                        }) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 20, weight: .medium))
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

                    // Two columns on portrait iPhones; four in the other layouts.
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(gameViewModel.labyrinths.enumerated()), id: \.element.id) { index, labyrinth in
                            let isLocked = gameViewModel.isLabyrinthLocked(at: index)
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
                                    Analytics.send("Paywall.entryTapped", with: ["source": paywallSource.rawValue])
                                    pendingLabyrinth = labyrinth
                                    parentalGateAction = .paywall
                                    showParentalGate = true
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
            gameViewModel.loadLabyrinths(packId: packId)
            autoOpenUITestLabyrinthIfNeeded()
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
                gameViewModel.loadLabyrinths(packId: packId)
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
                    case .account:
                        showAccount = true
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
        .sheet(isPresented: $showAccount) {
            NavigationStack {
                AccountView()
            }
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            if let lab = pendingLabyrinth, gameViewModel.isPremium {
                pendingLabyrinth = nil
                gameViewModel.selectLabyrinth(lab)
            } else {
                pendingLabyrinth = nil
            }
        }) {
            PaywallView(source: paywallSource)
        }
    }

    private var paywallSource: PaywallSource {
        PaywallSource.lockedLevel(in: packId)
    }

    private var parentalGatePurpose: ParentalGateView.Purpose {
        switch parentalGateAction {
        case .account: return .account
        case .difficultyPicker: return .settings
        case .paywall: return .paywall
        }
    }

    private var progressFraction: CGFloat {
        guard !gameViewModel.labyrinths.isEmpty else { return 0 }
        return CGFloat(progressTracker.completedCount(in: gameViewModel.labyrinths)) / CGFloat(gameViewModel.labyrinths.count)
    }

    private func autoOpenUITestLabyrinthIfNeeded() {
        guard !didAutoOpenUITestLabyrinth else { return }
        let arguments = ProcessInfo.processInfo.arguments
        var selected = (arguments.contains("-uiTestShowCompletionForLastLevel")
            || arguments.contains("-uiTestOpenLastLevel")) ? gameViewModel.labyrinths.last : nil
        #if DEBUG
        if let flag = arguments.firstIndex(of: "-uiTestOpenLevel"), flag + 1 < arguments.count,
           let number = Int(arguments[flag + 1]), gameViewModel.labyrinths.indices.contains(number - 1) {
            selected = gameViewModel.labyrinths[number - 1]
        }
        #endif
        guard let selected else { return }

        didAutoOpenUITestLabyrinth = true
        DispatchQueue.main.async {
            gameViewModel.selectLabyrinth(selected)
        }
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
                        } else if let backgroundImage = labyrinth.pathData.backgroundImage {
                            Image(backgroundImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
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

                if labyrinth.pathData.mazeType == "printable" {
                    VStack {
                        HStack {
                            Text(LocalizedStringKey(labyrinth.difficulty.capitalized))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.65))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(6)
                }

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
    @EnvironmentObject var preferences: UserPreferences

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
        .environment(\.locale, preferences.appLanguage.locale)
        .environment(\.layoutDirection, preferences.appLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
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
