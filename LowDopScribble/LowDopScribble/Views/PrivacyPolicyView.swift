import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Privacy Policy")
                            .font(.system(size: 24, weight: .bold, design: .rounded))

                        Text("Last updated: April 14, 2026")
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
                        bullet("Narration preference (on/off)")
                        bullet("Whether onboarding has been completed")
                        bullet("Completed labyrinth progress")
                        Text("This data is stored on your device using local app storage. We do not use it to identify you.")
                    }

                    section("Third-Party Services") {
                        Text("The App does not contain ads. The App uses:")
                        bullet("TelemetryDeck for anonymous analytics")
                        bullet("Apple's App Store / StoreKit for optional purchases, purchase restoration, and subscription management")
                    }

                    section("Analytics") {
                        Text("We use TelemetryDeck to collect anonymous usage statistics, such as onboarding steps, gameplay events, difficulty selection, and which paywall entry point was used. We use this information to understand which parts of the App are helpful and which need improvement.")
                        Text("We do not send names, email addresses, photos, recordings, contacts, or precise location through analytics. Learn more at telemetrydeck.com.")
                    }

                    section("In-App Purchases") {
                        Text("The App offers optional subscriptions and a lifetime purchase processed through Apple's App Store. We do not receive or store your full payment information. Purchase decisions are protected by a parental gate.")
                    }

                    section("Audio Content") {
                        Text("Audio narration used by the App is bundled with the App itself. The App does not record your voice and does not collect audio from your device.")
                    }

                    section("Children's Privacy (COPPA)") {
                        Text("This App complies with the Children's Online Privacy Protection Act (COPPA). We do not knowingly collect personal information from children under 13. Since we collect no personal information at all, no parental consent for data collection is required.")
                    }

                    section("Data Sharing") {
                        Text("We do not sell personal data and we do not share personal information for advertising. Limited app activity data is sent to TelemetryDeck for anonymous analytics, and purchase-related information is processed by Apple when you use in-app purchases.")
                    }

                    section("Data Retention") {
                        Text("Local app data remains on your device until you remove the App or clear the device data. Analytics data is retained by TelemetryDeck according to their service practices. Purchase records are retained by Apple according to App Store policies.")
                    }

                    section("Changes to This Policy") {
                        Text("If we make changes to this policy, we will update the date at the top and notify users through an App update.")
                    }

                    section("Contact Us") {
                        Text("If you have questions about this privacy policy or our practices, please contact us at:")
                        Text("privacy@lowdopamine.com")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(AppColor.accentBlue)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(AppColor.background)
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
                .foregroundColor(AppColor.textPrimary)
            content()
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(AppColor.textPrimary.opacity(0.85))
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
            Text(text)
        }
        .font(.system(size: 15, design: .rounded))
        .foregroundColor(AppColor.textPrimary.opacity(0.85))
    }
}
