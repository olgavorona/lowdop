import SwiftUI

struct CompletionView: View {
    let labyrinth: Labyrinth
    let onNext: () -> Void
    let onRepeat: () -> Void
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Character celebration
            VStack(spacing: 8) {
                CharacterMarkerView(
                    character: labyrinth.characterEnd,
                    scale: 2.5,
                    isStart: false
                )
                if let name = labyrinth.characterEnd.name {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                }
            }

            Text(labyrinth.completionMessage)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Educational section
            VStack(spacing: 12) {
                Text(labyrinth.educationalQuestion)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(Color(hex: "#F1C40F") ?? .yellow)
                    Text(labyrinth.funFact)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(hex: "#FFF8E7") ?? Color(.systemBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button(action: onNext) {
                    HStack {
                        Text("Next Labyrinth")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "#6BBF7B") ?? .green)
                    .cornerRadius(16)
                }

                Button(action: onRepeat) {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(height: 44)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .padding(20)
        .onAppear {
            if preferences.ttsEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let intro = labyrinth.characterEnd.name.map { "You found \($0)! " } ?? ""
                    ttsService.speak(
                        "\(intro)\(labyrinth.completionMessage) \(labyrinth.educationalQuestion)",
                        rate: preferences.ttsRate
                    )
                }
            }
        }
    }
}
