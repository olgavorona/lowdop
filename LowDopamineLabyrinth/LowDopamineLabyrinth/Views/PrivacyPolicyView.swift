import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Privacy Policy")
                            .font(.system(size: 24, weight: .bold, design: .rounded))

                        Text("Last updated: February 24, 2026")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)

                        Text("Low Dopamine Labyrinth (\"the App\") is designed for children ages 3-6. We take your child's privacy very seriously. This policy describes how we handle information in our App.")
                            .font(.system(size: 15, design: .rounded))
                    }

                    section("Data We Collect") {
                        Text("We do not collect any personal information from children or adults. Specifically:")
                        bullet("We do not collect names, email addresses, phone numbers, or physical addresses")
                        bullet("We do not collect photos, videos, or audio recordings")
                        bullet("We do not collect location data")
                        bullet("We do not use device identifiers for tracking")
                        bullet("We do not use cookies or similar technologies")
                    }

                    section("Local Storage") {
                        Text("The App stores a small amount of non-personal data on your device only (never transmitted):")
                        bullet("Selected difficulty level")
                        bullet("Sound preference (on/off)")
                        bullet("Completed labyrinth progress")
                        bullet("Subscription status")
                        Text("This data stays on your device and is never sent to us or any third party.")
                    }

                    section("Third-Party Services") {
                        Text("The only third-party service used is TelemetryDeck for anonymous analytics (see below). The App does not contain ads of any kind.")
                    }

                    section("Analytics") {
                        Text("We use TelemetryDeck to collect anonymous usage statistics (e.g., which mazes are played, which difficulty levels are popular). TelemetryDeck does not collect personal information, IP addresses, or device identifiers. All data is fully anonymous and cannot be linked to any individual user. Learn more at telemetrydeck.com.")
                    }

                    section("In-App Purchases") {
                        Text("The App offers optional subscriptions processed entirely through Apple's App Store. We do not receive or store any payment information. Purchase decisions are protected by a parental gate.")
                    }

                    section("Audio Content") {
                        Text("Pre-recorded audio narration is bundled with the App. For future content, audio files may be downloaded from our servers. No personal data is sent during these downloads.")
                    }

                    section("Children's Privacy (COPPA)") {
                        Text("This App complies with the Children's Online Privacy Protection Act (COPPA). We do not knowingly collect personal information from children under 13. Since we collect no personal information at all, no parental consent for data collection is required.")
                    }

                    section("Data Sharing") {
                        Text("We do not share any data with third parties. Period.")
                    }

                    section("Data Retention") {
                        Text("All App data is stored locally on your device. You can delete all App data at any time by deleting the App from your device.")
                    }

                    section("Changes to This Policy") {
                        Text("If we make changes to this policy, we will update the date at the top and notify users through an App update.")
                    }

                    section("Contact Us") {
                        Text("If you have questions about this privacy policy or our practices, please contact us at:")
                        Text("privacy@lowdopamine.com")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#5BA8D9") ?? .blue)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(hex: "#FFF8E7") ?? Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
            content()
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(Color(hex: "#5D4E37")?.opacity(0.85) ?? .primary)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
            Text(text)
        }
        .font(.system(size: 15, design: .rounded))
        .foregroundColor(Color(hex: "#5D4E37")?.opacity(0.85) ?? .primary)
    }
}
