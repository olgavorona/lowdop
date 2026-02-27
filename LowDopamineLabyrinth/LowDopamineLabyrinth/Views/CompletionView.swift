import SwiftUI

struct CompletionView: View {
    let labyrinth: Labyrinth
    let onNext: () -> Void
    let onRepeat: () -> Void
    var collectedCount: Int = 0
    var totalItemCount: Int = 0
    var isStoryComplete: Bool = false
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// iPhone landscape = compact, iPad = regular
    private var isCompact: Bool { verticalSizeClass == .compact }

    private var itemStatsText: String? {
        guard let _ = labyrinth.itemRule, let emoji = labyrinth.itemEmoji else { return nil }
        return "You collected \(collectedCount)/\(totalItemCount) \(emoji)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: isCompact ? 4 : 20) {
                // Character celebration
                CharacterMarkerView(
                    character: labyrinth.characterEnd,
                    scale: isCompact ? 1.3 : 2.5,
                    isStart: false
                )

                // Story-complete celebration header
                if isStoryComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppColor.accentYellow)
                            .font(.system(size: isCompact ? 20 : 28))
                        Text("Story Complete!")
                            .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColor.textPrimary)
                        Image(systemName: "star.fill")
                            .foregroundColor(AppColor.accentYellow)
                            .font(.system(size: isCompact ? 20 : 28))
                    }
                    .padding(.bottom, isCompact ? 2 : 4)
                }

                Text(labyrinth.completionMessage)
                    .font(.system(size: isCompact ? 18 : 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Item stats
                if let statsText = itemStatsText {
                    Text(statsText)
                        .font(.system(size: isCompact ? 15 : 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.accentBlue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Educational section
                VStack(spacing: isCompact ? 4 : 12) {
                    Text(labyrinth.educationalQuestion)
                        .font(.system(size: isCompact ? 14 : 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(AppColor.accentYellow)
                        Text(labyrinth.funFact)
                            .font(.system(size: isCompact ? 13 : 14, design: .rounded))
                            .foregroundColor(AppColor.textSecondary)
                    }
                    .padding(isCompact ? 6 : 16)
                    .background(AppColor.background)
                    .cornerRadius(12)
                }
                .padding(.horizontal, isCompact ? 16 : 24)

                // Actions
                VStack(spacing: isCompact ? 2 : 12) {
                    Button(action: onNext) {
                        HStack {
                            if isStoryComplete {
                                Image(systemName: "books.vertical")
                                Text("Back to Bookshelf")
                                    .font(.system(size: isCompact ? 16 : 20, weight: .bold, design: .rounded))
                            } else {
                                Text("Next Labyrinth")
                                    .font(.system(size: isCompact ? 16 : 20, weight: .bold, design: .rounded))
                                Image(systemName: "arrow.right")
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: isCompact ? 34 : 56)
                        .background(isStoryComplete
                            ? (AppColor.accentBlue)
                            : (AppColor.accentGreen))
                        .cornerRadius(isCompact ? 10 : 16)
                    }

                    Button(action: onRepeat) {
                        Text("Try Again")
                            .font(.system(size: isCompact ? 13 : 16, weight: .medium, design: .rounded))
                            .foregroundColor(AppColor.textTertiary)
                    }
                    .frame(height: isCompact ? 22 : 44)
                }
                .padding(.horizontal, isCompact ? 16 : 40)
                .padding(.top, isCompact ? 8 : 0)
                .padding(.bottom, isCompact ? 4 : 24)
            }
            .padding(.top, isCompact ? 6 : 20)
        }
        .background(Color.white)
        .cornerRadius(isCompact ? 16 : 24)
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .padding(isCompact ? 6 : 20)
        .onAppear {
            // Stop any instruction audio that may still be playing
            ttsService.stop()
            // Play completion narration after a brief pause
            if preferences.ttsEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ttsService.playAudio(labyrinth.audioCompletion)
                }
            }
        }
    }
}
