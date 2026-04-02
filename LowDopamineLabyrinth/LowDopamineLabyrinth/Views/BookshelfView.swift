import SwiftUI

struct BookshelfView: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var progressTracker: ProgressTracker
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    let onPackSelected: (String) -> Void

    @State private var oceanStories: [StoryInfo] = []
    @State private var spaceStories: [StoryInfo] = []
    @State private var showParentalGate = false
    @State private var showDifficultyPicker = false
    @State private var showAccount = false
    @State private var parentalGateAction: BookshelfParentalGateAction = .account

    private enum BookshelfParentalGateAction {
        case account
        case difficultyPicker
    }

    var body: some View {
        ZStack {
            // Cream background
            AppColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Title
                Text("Your Adventures")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .padding(.bottom, 24)

                // Pack cards area
                packCardsArea

                Spacer()
            }
        }
        .onAppear {
            oceanStories = LabyrinthLoader.shared.loadStories(packId: "ocean_adventures")
            spaceStories = LabyrinthLoader.shared.loadStories(packId: "space_adventures")
            Analytics.send("Bookshelf.opened", with: [
                "difficulty": preferences.difficultyLevel.rawValue,
                "storyCount": String(oceanStories.count + spaceStories.count)
            ])
        }
        .fullScreenCover(isPresented: $showParentalGate) {
            ParentalGateView(
                purpose: parentalGateAction == .account ? .account : .settings,
                onSuccess: {
                    showParentalGate = false
                    switch parentalGateAction {
                    case .account:
                        showAccount = true
                    case .difficultyPicker:
                        showDifficultyPicker = true
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

            // Difficulty badge
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

    // MARK: - Pack Cards

    private var packCardsArea: some View {
        Group {
            if oceanStories.isEmpty && spaceStories.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        oceanAdventuresCard
                        spaceAdventuresCard
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

    // MARK: - Ocean Adventures Card

    private var oceanAdventuresCard: some View {
        let completedStoryCount = oceanStories.filter { story in
            story.labyrinthIds.allSatisfy { progressTracker.isCompleted($0) }
        }.count
        let totalStoryCount = oceanStories.count

        return Button(action: {
            Analytics.send("Bookshelf.packTapped", with: ["pack": "ocean_adventures"])
            onPackSelected("ocean_adventures")
        }) {
            VStack(spacing: 0) {
                // Cover area with ocean gradient
                ZStack {
                    // Ocean gradient background
                    LinearGradient(
                        colors: [
                            Color(hex: "#4FC3F7") ?? .blue,
                            AppColor.linkBlue,
                            Color(hex: "#01579B") ?? .blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Decorative wave shapes
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

                    // Pack title on cover
                    VStack(spacing: 8) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.9))

                        Text("Ocean Adventures")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("\(totalStoryCount) stories")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(height: 200)

                // Bottom info area
                VStack(spacing: 10) {
                    // Progress text
                    HStack {
                        Text("\(completedStoryCount) of \(totalStoryCount) stories completed")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppColor.textSecondary)
                        Spacer()
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "#4FC3F7") ?? .blue)
                                .frame(
                                    width: totalStoryCount > 0
                                        ? CGFloat(completedStoryCount) / CGFloat(totalStoryCount) * geo.size.width
                                        : 0,
                                    height: 6
                                )
                        }
                    }
                    .frame(height: 6)

                    // Tap to play prompt
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
            .frame(width: 280)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Space Adventures Card

    private var spaceAdventuresCard: some View {
        let completedStoryCount = spaceStories.filter { story in
            story.labyrinthIds.allSatisfy { progressTracker.isCompleted($0) }
        }.count
        let totalStoryCount = spaceStories.count
        let isLocked = !subscriptionManager.isPremium

        return Button(action: {
            if isLocked {
                // Tapping locked pack opens paywall (handled via bookshelf parental gate)
                parentalGateAction = .account
                showParentalGate = true
            } else {
                Analytics.send("Bookshelf.packTapped", with: ["pack": "space_adventures"])
                onPackSelected("space_adventures")
            }
        }) {
            VStack(spacing: 0) {
                // Cover area with space gradient
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(hex: "#1A1A2E") ?? .black,
                            Color(hex: "#16213E") ?? .indigo,
                            Color(hex: "#0F3460") ?? .blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Stars decoration
                    ForEach(0..<12, id: \.self) { i in
                        let xPos = CGFloat((i * 23 + 15) % 260) + 10
                        let yPos = CGFloat((i * 17 + 20) % 160) + 10
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: i % 3 == 0 ? 4 : 2)
                            .position(x: xPos, y: yPos)
                    }

                    // Lock badge
                    if isLocked {
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

                    // Pack title on cover
                    VStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow.opacity(0.9))

                        Text("Denny in Space")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("\(totalStoryCount) stories")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(height: 200)

                // Bottom info area
                VStack(spacing: 10) {
                    HStack {
                        if isLocked {
                            Text("Unlock to explore space!")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(AppColor.textSecondary)
                        } else {
                            Text("\(completedStoryCount) of \(totalStoryCount) stories completed")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(AppColor.textSecondary)
                        }
                        Spacer()
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "#0F3460") ?? .blue)
                                .frame(
                                    width: (!isLocked && totalStoryCount > 0)
                                        ? CGFloat(completedStoryCount) / CGFloat(totalStoryCount) * geo.size.width
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
            .frame(width: 280)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
            .opacity(isLocked ? 0.85 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
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
