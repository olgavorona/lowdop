import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    @State private var showParentalGate = false
    var onSkip: (() -> Void)? = nil

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

            // MARK: - Right Column: Single Product + CTA
            VStack(spacing: 12) {
                Spacer()

                if let product = subscriptionManager.product {
                    // Product display
                    Text(product.displayName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#5D4E37") ?? .brown)

                    Text(product.displayPrice)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#5BA8D9") ?? .blue)

                    Text("Buy once, play forever")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.7))
                } else {
                    Text("Loading...")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor((Color(hex: "#5D4E37") ?? .brown).opacity(0.7))
                }

                // CTA button
                Button(action: {
                    showParentalGate = true
                }) {
                    Text("Unlock All Adventures")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "#5BA8D9") ?? .blue)
                        .cornerRadius(14)
                }
                .disabled(isPurchasing || subscriptionManager.product == nil)
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
                    Analytics.send("Paywall.dismissed")
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
                purpose: .paywall,
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

    private func executePurchase() {
        guard let product = subscriptionManager.product else { return }
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
