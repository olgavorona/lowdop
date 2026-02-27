import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var preferences: UserPreferences
    @State private var showPrivacyPolicy = false

    private let levelColors: [DifficultyLevel: [Color]] = [
        .easy: [Color(hex: "#81C784") ?? .green, Color(hex: "#66BB6A") ?? .green],
        .medium: [Color(hex: "#FFB74D") ?? .orange, Color(hex: "#FFA726") ?? .orange],
        .hard: [Color(hex: "#EF5350") ?? .red, Color(hex: "#E53935") ?? .red],
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Your Challenge")
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
                        preferences.difficultyLevel = level
                        preferences.hasCompletedOnboarding = true
                        Analytics.send("Onboarding.difficultySelected", with: ["level": level.rawValue])
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: { showPrivacyPolicy = true }) {
                Text("Privacy Policy")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(AppColor.textTertiary)
                    .underline()
            }
            .padding(.bottom, 16)
        }
        .padding()
        .background(AppColor.background)
        .ignoresSafeArea()
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
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

struct DifficultyCard: View {
    let level: DifficultyLevel
    let colors: [Color]
    let samplePath: String
    let action: () -> Void

    private var levelNumber: Int {
        switch level {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Mini maze preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    if !samplePath.isEmpty {
                        GeometryReader { geo in
                            let scale = min(geo.size.width, geo.size.height) / 600
                            SVGPathParser.parse(samplePath, scale: scale)
                                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                        }
                        .padding(8)
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)

                // Level name
                Text(level.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)

                // Difficulty dots
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < levelNumber ? colors[0] : Color.gray.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
