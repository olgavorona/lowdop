import SwiftUI

struct BookshelfView: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var progressTracker: ProgressTracker
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    let onPackSelected: (String) -> Void

    @State private var storiesByPack: [String: [StoryInfo]] = [:]
    @State private var showParentalGate = false
    @State private var showDifficultyPicker = false
    @State private var showAccount = false
    @State private var showPaywall = false
    @State private var parentalGateAction: BookshelfParentalGateAction = .account

    private enum BookshelfParentalGateAction {
        case account, difficultyPicker, paywall
    }

    // MARK: - Pack Configuration

    private struct PackConfig: Identifiable {
        let id: String
        let title: String
        let gradientColors: [Color]
        let progressBarColor: Color
        let unlockText: String
        let icon: PackIcon
        let decoration: PackDecoration
        let alwaysShow: Bool

        enum PackIcon {
            case system(String, Color)
            case emoji(String)
        }

        enum PackDecoration {
            case waves
            case stars
            case leaves
        }
    }

    private static let packs: [PackConfig] = [
        PackConfig(
            id: "ocean_adventures",
            title: "Ocean Adventures",
            gradientColors: [Color(hex: "#4FC3F7") ?? .blue, AppColor.linkBlue, Color(hex: "#01579B") ?? .blue],
            progressBarColor: Color(hex: "#4FC3F7") ?? .blue,
            unlockText: "",
            icon: .system("water.waves", .white.opacity(0.9)),
            decoration: .waves,
            alwaysShow: true
        ),
        PackConfig(
            id: "space_adventures",
            title: "Denny in Space",
            gradientColors: [Color(hex: "#1A1A2E") ?? .black, Color(hex: "#16213E") ?? .indigo, Color(hex: "#0F3460") ?? .blue],
            progressBarColor: Color(hex: "#0F3460") ?? .blue,
            unlockText: "Unlock to explore space!",
            icon: .system("star.fill", .yellow.opacity(0.9)),
            decoration: .stars,
            alwaysShow: true
        ),
        PackConfig(
            id: "forest_adventures",
            title: "Denny in the Forest",
            gradientColors: [Color(hex: "#1A3D1A") ?? .green, Color(hex: "#2D5A27") ?? .green, Color(hex: "#4A7C3F") ?? .green],
            progressBarColor: Color(hex: "#2D5A27") ?? .green,
            unlockText: "Unlock to explore the forest!",
            icon: .emoji("🌲"),
            decoration: .leaves,
            alwaysShow: false
        ),
    ]

    var body: some View {
        ZStack {
            AppColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Text("Your Adventures")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .padding(.bottom, 24)

                packCardsArea

                Spacer()
            }
        }
        .onAppear {
            for config in Self.packs {
                storiesByPack[config.id] = LabyrinthLoader.shared.loadStories(packId: config.id)
            }
            let totalLoaded = storiesByPack.values.reduce(0) { $0 + $1.count }
            Analytics.send("Bookshelf.opened", with: [
                "difficulty": preferences.difficultyLevel.rawValue,
                "storyCount": String(totalLoaded)
            ])
        }
        .fullScreenCover(isPresented: $showParentalGate) {
            ParentalGateView(
                purpose: {
                    switch parentalGateAction {
                    case .account: return .account
                    case .difficultyPicker: return .settings
                    case .paywall: return .paywall
                    }
                }(),
                onSuccess: {
                    showParentalGate = false
                    switch parentalGateAction {
                    case .account: showAccount = true
                    case .difficultyPicker: showDifficultyPicker = true
                    case .paywall: showPaywall = true
                    }
                },
                onCancel: { showParentalGate = false }
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showAccount) {
            NavigationStack {
                AccountView()
            }
        }
        .sheet(isPresented: $showDifficultyPicker) {
            DifficultyPickerSheet(onSelect: { newLevel in
                let oldLevel = preferences.difficultyLevel
                preferences.difficultyLevel = newLevel
                showDifficultyPicker = false
                Analytics.send("Bookshelf.difficultyChanged", with: [
                    "from": oldLevel.rawValue,
                    "to": newLevel.rawValue
                ])
            })
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()
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
    }

    // MARK: - Pack Cards Area

    private var packCardsArea: some View {
        let visiblePacks = Self.packs.filter { config in
            config.alwaysShow || !(storiesByPack[config.id]?.isEmpty ?? true)
        }
        let allEmpty = storiesByPack.isEmpty || storiesByPack.values.allSatisfy { $0.isEmpty }

        return Group {
            if allEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(visiblePacks) { config in
                            packCard(config: config, stories: storiesByPack[config.id] ?? [])
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(AppColor.textPrimary.opacity(0.5))
            Text("No adventures available")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(AppColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pack Card

    private func packCard(config: PackConfig, stories: [StoryInfo]) -> some View {
        let completedCount = stories.filter { story in
            story.labyrinthIds.allSatisfy { progressTracker.isCompleted($0) }
        }.count
        let totalCount = stories.count
        let freeStoryCount = stories.filter(\.isFree).count
        let isLocked = freeStoryCount == 0 && !subscriptionManager.isPremium

        return Button(action: {
            if isLocked {
                parentalGateAction = .paywall
                showParentalGate = true
                Analytics.send("Paywall.shown", with: ["trigger": "bookshelf"])
            } else {
                Analytics.send("Bookshelf.packTapped", with: ["pack": config.id])
                onPackSelected(config.id)
            }
        }) {
            VStack(spacing: 0) {
                packCover(config: config, totalCount: totalCount, isLocked: isLocked)
                    .frame(height: 200)
                packBottom(config: config, completedCount: completedCount, totalCount: totalCount, isLocked: isLocked)
            }
            .frame(width: 280)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
            .opacity(isLocked ? 0.85 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func packCover(config: PackConfig, totalCount: Int, isLocked: Bool) -> some View {
        ZStack {
            LinearGradient(colors: config.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)

            packDecoration(config.decoration)

            if isLocked {
                premiumBadge
            }

            VStack(spacing: 8) {
                packIconView(config.icon)
                Text(config.title)
                    .font(.system(size: config.title.count > 16 ? 22 : 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("\(totalCount) stories")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private func packBottom(config: PackConfig, completedCount: Int, totalCount: Int, isLocked: Bool) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(isLocked ? config.unlockText : "\(completedCount) of \(totalCount) stories completed")
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
                            width: (!isLocked && totalCount > 0)
                                ? CGFloat(completedCount) / CGFloat(totalCount) * geo.size.width
                                : 0,
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            HStack {
                Spacer()
                Text(isLocked ? "Tap to unlock" : "Tap to play")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isLocked ? AppColor.accentGreen : AppColor.linkBlue)
                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isLocked ? AppColor.accentGreen : AppColor.linkBlue)
            }
        }
        .padding(16)
        .background(Color.white)
    }

    @ViewBuilder
    private func packDecoration(_ decoration: PackConfig.PackDecoration) -> some View {
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
    private func packIconView(_ icon: PackConfig.PackIcon) -> some View {
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

    private var premiumBadge: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Premium")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppColor.accentGreen.opacity(0.9))
                .cornerRadius(10)
                .padding(12)
            }
            Spacer()
        }
    }
}

// MARK: - Wave Shape

/// A simple wave shape for decorative use on the pack card.
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
