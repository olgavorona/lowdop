import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Terms of Use")
                            .font(.system(size: 24, weight: .bold, design: .rounded))

                        Text("Last updated: February 24, 2026")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)

                        Text("These Terms of Use (\"Terms\") govern your use of the Low Dopamine Labyrinth application (\"the App\"). By downloading or using the App, you agree to these Terms.")
                            .font(.system(size: 15, design: .rounded))
                    }

                    section("Description of Service") {
                        Text("Low Dopamine Labyrinth is an educational maze game designed for children ages 3-6. The App provides interactive labyrinth puzzles with ocean-themed stories and narration.")
                    }

                    section("Free and Premium Access") {
                        Text("The App offers limited free access (3 labyrinths initially, then 1 per day). Premium access unlocks all content and is available through auto-renewable subscriptions or a one-time lifetime purchase via Apple's App Store.")
                    }

                    section("Subscriptions") {
                        Text("Subscriptions are billed through your Apple ID account. By subscribing, you agree to the following:")
                        bullet("Payment is charged to your Apple ID account at confirmation of purchase")
                        bullet("Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period")
                        bullet("Your account is charged for renewal within 24 hours before the end of the current period")
                        bullet("You can manage and cancel subscriptions in your device's Settings > Apple ID > Subscriptions")
                        bullet("Any unused portion of a free trial is forfeited when you purchase a subscription")
                    }

                    section("Parental Responsibility") {
                        Text("This App is intended for use by children under parental supervision. In-app purchases are protected by a parental gate. Parents and guardians are responsible for managing their child's use of the App and any purchases made.")
                    }

                    section("Intellectual Property") {
                        Text("All content in the App, including characters, stories, artwork, audio narration, and maze designs, is owned by Low Dopamine Labyrinth and protected by copyright. You may not reproduce, distribute, or create derivative works from the App's content.")
                    }

                    section("Disclaimer of Warranties") {
                        Text("The App is provided \"as is\" without warranties of any kind. We do not guarantee that the App will be error-free or uninterrupted.")
                    }

                    section("Limitation of Liability") {
                        Text("To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, or consequential damages arising from your use of the App.")
                    }

                    section("Changes to These Terms") {
                        Text("We may update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the updated Terms.")
                    }

                    section("Contact Us") {
                        Text("If you have questions about these Terms, please contact us at:")
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
