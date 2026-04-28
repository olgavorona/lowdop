import SwiftUI

struct AccountView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Subscription
                SectionHeader(title: "Subscription")

                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                            .font(.system(size: 18))
                        Text(statusText)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColor.textPrimary)
                        Spacer()
                    }

                    if subscriptionManager.activeSubscriptionProductId != nil {
                        AccountButton(
                            title: "Get Forever Access",
                            icon: "infinity",
                            color: AppColor.accentYellow
                        ) {
                            Analytics.send("Paywall.entryTapped", with: ["source": PaywallSource.account.rawValue])
                            showPaywall = true
                        }

                        AccountButton(
                            title: "Manage Subscription",
                            icon: "arrow.triangle.2.circlepath",
                            color: AppColor.accentBlue
                        ) {
                            Task { await subscriptionManager.openSubscriptionManagement() }
                        }
                    }

                    AccountButton(
                        title: "Restore Purchases",
                        icon: "arrow.clockwise",
                        color: AppColor.accentGreen
                    ) {
                        Task { await subscriptionManager.restorePurchases() }
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)

                // MARK: - Legal
                SectionHeader(title: "Legal")

                VStack(spacing: 0) {
                    Link(destination: URL(string: "https://olgavorona.github.io/lowdop/privacy")!) {
                        AccountRow(title: "Privacy Policy", icon: "hand.raised.fill")
                    }
                    Divider().padding(.leading, 44)
                    Link(destination: URL(string: "https://olgavorona.github.io/lowdop/terms")!) {
                        AccountRow(title: "Terms of Service", icon: "doc.text.fill")
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
            PaywallView(source: .account)
        }
    }

    private var statusText: String {
        if subscriptionManager.isPremium {
            switch subscriptionManager.activeSubscriptionProductId {
            case "labyrinth_unlimited_weekly":  return "Weekly subscription"
            case "labyrinth_unlimited_monthly": return "Monthly subscription"
            default: return "Forever access"
            }
        }
        return "No active plan"
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
        Text(title.uppercased())
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
                Text(title)
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
            Text(title)
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
