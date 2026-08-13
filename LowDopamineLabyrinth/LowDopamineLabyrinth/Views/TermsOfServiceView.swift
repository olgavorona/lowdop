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
                        Text("The App offers limited free access (3 labyrinths initially, then 1 per day). Premium access unlocks all content and is available through a one-time purchase via Apple's App Store.")
                    }

                    section("In-App Purchase") {
                        Text("The one-time purchase is billed through your Apple ID account. By purchasing, you agree to the following:")
                        bullet("Payment is charged to your Apple ID account at confirmation of purchase")
                        bullet("The purchase unlocks premium access for the current App Store account")
                        bullet("You can restore purchases using the Restore Purchases button in the App")
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
