import SwiftUI

struct BookshelfView: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var progressTracker: ProgressTracker
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    let onPackSelected: (String) -> Void

    @State private var stories: [StoryInfo] = []
    @State private var showParentalGate = false
    @State private var showDifficultyPicker = false
    @State private var showPrivacyPolicy = false
    @State private var parentalGateAction: BookshelfParentalGateAction = .privacyPolicy

    private enum BookshelfParentalGateAction {
        case privacyPolicy
        case difficultyPicker
    }

    var body: some View {
        ZStack {
            // Cream background
            (Color(hex: "#FFF8E7") ?? Color(.systemBackground))
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
                    .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                    .padding(.bottom, 24)

                // Pack cards area
                packCardsArea

                Spacer()
            }
        }
        .onAppear {
            stories = LabyrinthLoader.shared.loadStories()
            Analytics.send("Bookshelf.opened", with: [
                "difficulty": preferences.difficultyLevel.rawValue,
                "storyCount": String(stories.count)
            ])
        }
        .fullScreenCover(isPresented: $showParentalGate) {
            ParentalGateView(
                purpose: parentalGateAction == .privacyPolicy ? .privacyPolicy : .settings,
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
    }

    // MARK: - Pack Cards

    private var packCardsArea: some View {
        Group {
            if stories.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        oceanAdventuresCard
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
                .foregroundColor(Color(hex: "#5D4E37")?.opacity(0.3) ?? .gray)
            Text("No adventures available")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37")?.opacity(0.5) ?? .gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ocean Adventures Card

    private var oceanAdventuresCard: some View {
        let completedStoryCount = countCompletedStories()
        let totalStoryCount = stories.count

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
                            Color(hex: "#0288D1") ?? .blue,
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
                            .foregroundColor(Color(hex: "#5D4E37")?.opacity(0.7) ?? .brown)
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
                            .foregroundColor(Color(hex: "#0288D1") ?? .blue)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#0288D1") ?? .blue)
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

    // MARK: - Helpers

    /// Count how many stories have all 3 difficulty levels completed.
    private func countCompletedStories() -> Int {
        stories.filter { story in
            story.labyrinthIds.allSatisfy { progressTracker.isCompleted($0) }
        }.count
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
