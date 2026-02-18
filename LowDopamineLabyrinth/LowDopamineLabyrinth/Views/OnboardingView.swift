import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var preferences: UserPreferences
    @State private var selectedAge: AgeGroup = .young
    @State private var showPrivacyPolicy = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Text("Welcome!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)

            Text("Let's set up your labyrinth adventure")
                .font(.system(size: 18, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("How old are you?")
                .font(.system(size: 22, weight: .medium, design: .rounded))

            HStack(spacing: 20) {
                AgeButton(title: "3-4", emoji: "🐣", isSelected: selectedAge == .young) {
                    selectedAge = .young
                }
                AgeButton(title: "5-6", emoji: "🌟", isSelected: selectedAge == .older) {
                    selectedAge = .older
                }
            }
            .padding(.horizontal)

            Spacer()

            Button(action: {
                preferences.ageGroup = selectedAge
                preferences.hasCompletedOnboarding = true
            }) {
                Text("Start!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "#6BBF7B") ?? .green)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)

            // Privacy policy — required by Apple during onboarding
            Button(action: { showPrivacyPolicy = true }) {
                Text("Privacy Policy")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
                    .underline()
            }
            .padding(.bottom, 16)
        }
        .padding()
        .background(Color(hex: "#FFF8E7") ?? Color(.systemBackground))
        .ignoresSafeArea()
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
}

struct AgeButton: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 44))
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : Color(hex: "#5D4E37") ?? .brown)
                Text("years")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(isSelected ? (Color(hex: "#6BBF7B") ?? .green) : Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}
