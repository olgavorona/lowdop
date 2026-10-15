import SwiftUI

struct AccountView: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var languageAudioPackManager: LanguageAudioPackManager
    @EnvironmentObject var reviewRequestManager: ReviewRequestManager
    @Environment(\.dismiss) var dismiss
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Language
                SectionHeader(title: "Language")

                VStack(alignment: .leading, spacing: 14) {
                    Picker("App language", selection: $preferences.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(AppLocalization.text(language.displayName)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)

                    if preferences.appLanguage == .english {
                        Text("English narration is included with the app.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppColor.textSecondary)
                    } else {
                        languagePackControls(for: preferences.appLanguage)
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)

                // MARK: - Purchase
                SectionHeader(title: "Purchase")

                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                            .font(.system(size: 18))
                        Text(AppLocalization.text(statusText))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColor.textPrimary)
                        Spacer()
                    }

                    if !subscriptionManager.isPremium {
                        AccountButton(
                            title: "Get Full Access",
                            icon: "infinity",
                            color: AppColor.accentYellow
                        ) {
                            Analytics.send("Paywall.entryTapped", with: ["source": PaywallSource.settings.rawValue])
                            showPaywall = true
                        }
                    }

                    AccountButton(
                        title: "Restore Purchases",
                        icon: "arrow.clockwise",
                        color: AppColor.accentGreen
                    ) {
                        Task { await subscriptionManager.restorePurchases() }
                    }

                    AccountButton(
                        title: "Rate the App",
                        icon: "star.fill",
                        color: AppColor.accentBlue
                    ) {
                        reviewRequestManager.requestFromAccountButton()
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)

                // MARK: - Legal
                SectionHeader(title: "Legal")

                VStack(spacing: 0) {
                    Link(destination: URL(string: "https://olgavorona.github.io/lowdop/support")!) {
                        AccountRow(title: "Support", icon: "questionmark.circle.fill")
                    }
                    Divider().padding(.leading, 44)
                    Link(destination: URL(string: "https://olgavorona.github.io/lowdop/privacy")!) {
                        AccountRow(title: "Privacy Policy", icon: "hand.raised.fill")
                    }
                    Divider().padding(.leading, 44)
                    Link(destination: URL(string: "https://olgavorona.github.io/lowdop/terms")!) {
                        AccountRow(title: "Terms of Use", icon: "doc.text.fill")
                    }
                }
                .background(Color.white)
                .cornerRadius(16)

                Spacer(minLength: 32)
            }
            .padding(20)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .settings)
        }
        .onAppear {
            reviewRequestManager.requestAfterFirstAccountOpen()
        }
        .task {
            await languageAudioPackManager.refreshStatus(for: preferences.appLanguage)
        }
        .onChange(of: preferences.appLanguage) { language in
            Analytics.send("Language.selected", with: [
                "language": language.rawValue,
                "app_locale": language.rawValue,
                "source": "settings"
            ])
            Task { await languageAudioPackManager.refreshStatus(for: language) }
        }
    }

    @ViewBuilder
    private func languagePackControls(for language: AppLanguage) -> some View {
        if languageAudioPackManager.downloadedLanguages.contains(language) {
            HStack {
                Label("Narration downloaded for offline use", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(AppColor.accentGreen)
                Spacer()
                Button("Remove") {
                    Task { await languageAudioPackManager.remove(language) }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
        } else {
            Button {
                Task { await languageAudioPackManager.download(language) }
            } label: {
                HStack(spacing: 10) {
                    if let progress = languageAudioPackManager.progress[language] {
                        ProgressView(value: progress)
                            .tint(.white)
                        Text("Downloading narration…")
                    } else {
                        Label("Download \(language.displayName) narration", systemImage: "arrow.down.circle")
                    }
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(AppColor.accentBlue)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(languageAudioPackManager.progress[language] != nil)
        }

        if let error = languageAudioPackManager.errors[language] {
            Text(AppLocalization.text(error))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.red)
        }
    }

    private var statusText: String {
        subscriptionManager.isPremium ? "Full access unlocked" : "No purchase found"
    }

    private var statusIcon: String {
        subscriptionManager.isPremium ? "checkmark.seal.fill" : "xmark.seal"
    }

    private var statusColor: Color {
        subscriptionManager.isPremium ? AppColor.accentGreen : AppColor.textTertiary
    }
}

// MARK: - Subviews

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(LocalizedStringKey(title))
            .textCase(.uppercase)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(AppColor.textTertiary)
            .padding(.horizontal, 4)
    }
}

private struct AccountButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(color)
                    .cornerRadius(8)
                Text(LocalizedStringKey(title))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AccountRow: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(AppColor.textTertiary)
                .font(.system(size: 14))
                .frame(width: 28)
            Text(LocalizedStringKey(title))
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColor.textFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
