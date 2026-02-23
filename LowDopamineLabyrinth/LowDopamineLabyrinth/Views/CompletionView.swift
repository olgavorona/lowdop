import SwiftUI

struct CompletionView: View {
    let labyrinth: Labyrinth
    let onNext: () -> Void
    let onRepeat: () -> Void
    var collectedCount: Int = 0
    var totalItemCount: Int = 0
    var avoidedItemHits: Int = 0
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// iPhone landscape = compact, iPad = regular
    private var isCompact: Bool { verticalSizeClass == .compact }

    private var itemStatsText: String? {
        guard let rule = labyrinth.itemRule, let emoji = labyrinth.itemEmoji else { return nil }
        if rule == "collect" {
            return "You collected \(collectedCount)/\(totalItemCount) \(emoji)"
        } else if rule == "avoid" {
            if avoidedItemHits == 0 {
                return "You avoided all the \(emoji)!"
            } else {
                return "You touched \(avoidedItemHits) \(emoji) — try to avoid them all!"
            }
        }
        return nil
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

                Text(labyrinth.completionMessage)
                    .font(.system(size: isCompact ? 18 : 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Item stats
                if let statsText = itemStatsText {
                    Text(statsText)
                        .font(.system(size: isCompact ? 15 : 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#5BA8D9") ?? .blue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Educational section
                VStack(spacing: isCompact ? 4 : 12) {
                    Text(labyrinth.educationalQuestion)
                        .font(.system(size: isCompact ? 14 : 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(Color(hex: "#F1C40F") ?? .yellow)
                        Text(labyrinth.funFact)
                            .font(.system(size: isCompact ? 13 : 14, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(isCompact ? 6 : 16)
                    .background(Color(hex: "#FFF8E7") ?? Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal, isCompact ? 16 : 24)

                // Actions
                VStack(spacing: isCompact ? 2 : 12) {
                    Button(action: onNext) {
                        HStack {
                            Text("Next Labyrinth")
                                .font(.system(size: isCompact ? 16 : 20, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: isCompact ? 34 : 56)
                        .background(Color(hex: "#6BBF7B") ?? .green)
                        .cornerRadius(isCompact ? 10 : 16)
                    }

                    Button(action: onRepeat) {
                        Text("Try Again")
                            .font(.system(size: isCompact ? 13 : 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
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
