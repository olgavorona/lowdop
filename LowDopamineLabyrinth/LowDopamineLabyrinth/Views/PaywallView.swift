import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    @State private var selectedProductID: String = "labyrinth_unlimited_yearly"
    @State private var showParentalGate = false
    var onSkip: (() -> Void)? = nil

    private let yearlyID = "labyrinth_unlimited_yearly"
    private let lifetimeID = "labyrinth_unlimited_lifetime"

    private let benefits = [
        "100 mazes across 20 ocean stories",
        "Calm, focused screen time",
        "Educational facts & narration"
    ]

    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left Column: Hero + Benefits
            VStack(spacing: 16) {
                Spacer()

                Image("denny")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)

                Text("Unlock All Adventures")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#5D4E37") ?? .brown)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "#6BBF7B") ?? .green)
                                .font(.system(size: 16))
                            Text(benefit)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                        }
                    }
                }

                Spacer()

                // Auto-renewal terms
                Text("Subscriptions auto-renew until cancelled. Cancel anytime in Settings > Subscriptions.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                // Restore + Terms + Privacy
                HStack(spacing: 12) {
                    Button("Restore Purchases") {
                        Analytics.send("Paywall.restoreTapped")
                        Task { await subscriptionManager.restorePurchases() }
                    }
                    Text("|")
                        .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.3))
                    Link("Terms", destination: URL(string: "https://olgavorona.github.io/lowdop/terms")!)
                    Text("|")
                        .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.3))
                    Link("Privacy", destination: URL(string: "https://olgavorona.github.io/lowdop/privacy")!)
                }
                .font(.system(size: 12, design: .rounded))
                .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.6))
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)

            // MARK: - Right Column: Plan Cards + CTA
            VStack(spacing: 12) {
                Spacer()

                // Plan selector cards
                ForEach(subscriptionManager.products, id: \.id) { product in
                    PlanCard(
                        product: product,
                        isSelected: selectedProductID == product.id,
                        isYearly: product.id == yearlyID,
                        isLifetime: product.id == lifetimeID
                    )
                    .onTapGesture {
                        selectedProductID = product.id
                        Analytics.send("Paywall.planSelected", with: ["productId": product.id])
                    }
                }

                if subscriptionManager.products.isEmpty {
                    Text("Loading plans...")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.7))
                }

                // CTA button
                Button(action: {
                    showParentalGate = true
                }) {
                    Text(ctaText)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "#5BA8D9") ?? .blue)
                        .cornerRadius(14)
                }
                .disabled(isPurchasing || subscriptionManager.products.isEmpty)
                .opacity(isPurchasing ? 0.6 : 1.0)
                .padding(.top, 4)

                #if DEBUG
                Button(action: {
                    onSkip?()
                    dismiss()
                }) {
                    Text("Skip (Dev)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color(hex: "#6BBF7B") ?? .green)
                        .cornerRadius(10)
                }
                #endif

                Button(action: {
                    Analytics.send("Paywall.dismissed", with: ["selectedPlan": selectedProductID])
                    dismiss()
                }) {
                    Text("Maybe Later")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.6))
                }
                .frame(height: 36)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .background(Color(hex: "#FFF8E7") ?? Color(.systemBackground))
        .task {
            await subscriptionManager.loadProducts()
        }
        .fullScreenCover(isPresented: $showParentalGate) {
            ParentalGateView(
                onSuccess: {
                    showParentalGate = false
                    executePurchase()
                },
                onCancel: {
                    showParentalGate = false
                }
            )
        }
    }

    private var ctaText: String {
        if selectedProductID == yearlyID {
            return "Start Free Trial"
        } else if selectedProductID == lifetimeID {
            return "Buy Once"
        } else {
            return "Subscribe"
        }
    }

    private func executePurchase() {
        guard let product = subscriptionManager.products.first(where: { $0.id == selectedProductID }) else { return }
        Analytics.send("Paywall.purchaseAttempted", with: ["productId": product.id])
        Task {
            isPurchasing = true
            let success = await subscriptionManager.purchase(product)
            isPurchasing = false
            if success {
                Analytics.send("Paywall.purchaseSucceeded", with: ["productId": product.id])
                dismiss()
            }
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let isYearly: Bool
    let isLifetime: Bool

    var body: some View {
        HStack {
            // Radio circle
            ZStack {
                Circle()
                    .stroke(isSelected ? Color(hex: "#5BA8D9") ?? .blue : Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(Color(hex: "#5BA8D9") ?? .blue)
                        .frame(width: 14, height: 14)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(product.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                    if isYearly {
                        Text("Best Value")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#F1C40F") ?? .yellow)
                            .cornerRadius(6)
                    }
                }
                if isYearly {
                    Text("7-day free trial")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color(hex: "#6BBF7B") ?? .green)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(product.displayPrice)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#5D4E37") ?? .brown)
                if isYearly, let monthly = monthlyEquivalent(product) {
                    Text(monthly)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.5))
                }
                if isLifetime {
                    Text("one-time")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? (Color(hex: "#5BA8D9")?.opacity(0.08) ?? .blue.opacity(0.08)) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? (Color(hex: "#5BA8D9") ?? .blue) : Color.gray.opacity(0.15), lineWidth: isSelected ? 2 : 1)
        )
    }

    private func monthlyEquivalent(_ product: Product) -> String? {
        let monthly = product.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        guard let str = formatter.string(from: monthly as NSDecimalNumber) else { return nil }
        return "\(str)/month"
    }
}
