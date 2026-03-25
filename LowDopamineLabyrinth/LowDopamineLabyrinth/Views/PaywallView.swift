import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    @State private var selectedProductId: String = "labyrinth_unlimited_lifetime1"
    var onSkip: (() -> Void)? = nil

    private let benefits = [
        "60 mazes across 20 ocean stories",
        "Calm, focused screen time",
        "Educational facts & narration"
    ]

    private var selectedProduct: Product? {
        subscriptionManager.products.first { $0.id == selectedProductId }
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left Column: Hero + Benefits
            VStack(spacing: 16) {
                Spacer()

                Image("denny")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)

                Text("Unlock All Packs")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColor.accentGreen)
                                .font(.system(size: 16))
                            Text(benefit)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(AppColor.textPrimary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button("Restore Purchases") {
                        Analytics.send("Paywall.restoreTapped")
                        Task { await subscriptionManager.restorePurchases() }
                    }
                    Text("|")
                        .foregroundColor(AppColor.textFaint)
                    Link("Terms", destination: URL(string: "https://olgavorona.github.io/lowdop/terms")!)
                    Text("|")
                        .foregroundColor(AppColor.textFaint)
                    Link("Privacy", destination: URL(string: "https://olgavorona.github.io/lowdop/privacy")!)
                }
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppColor.textTertiary)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)

            // MARK: - Right Column: Plan Cards + CTA
            VStack(spacing: 12) {
                Spacer()

                if subscriptionManager.products.isEmpty {
                    ProgressView()
                        .padding()
                } else {
                    VStack(spacing: 8) {
                        ForEach(subscriptionManager.products, id: \.id) { product in
                            PlanCardView(
                                product: product,
                                isSelected: selectedProductId == product.id,
                                isBestValue: product.id == "labyrinth_unlimited_lifetime1"
                            ) {
                                selectedProductId = product.id
                            }
                        }
                    }
                }

                Button(action: executePurchase) {
                    Group {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(ctaTitle)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .background(AppColor.accentBlue)
                .cornerRadius(14)
                .disabled(isPurchasing || selectedProduct == nil)
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
                        .background(AppColor.accentGreen)
                        .cornerRadius(10)
                }
                #endif

                Button(action: {
                    Analytics.send("Paywall.dismissed")
                    dismiss()
                }) {
                    Text("Maybe Later")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppColor.textTertiary)
                }
                .frame(height: 36)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .background(AppColor.background)
        .task {
            await subscriptionManager.loadProducts()
        }
    }

    private var ctaTitle: String {
        guard let product = selectedProduct else { return "Subscribe" }
        if let intro = product.subscription?.introductoryOffer, intro.paymentMode == .freeTrial {
            return "Try Free & Subscribe"
        }
        if product.id == "labyrinth_unlimited_lifetime1" {
            return "Buy Once, Play Forever"
        }
        return "Subscribe"
    }

    private func executePurchase() {
        guard let product = selectedProduct else { return }
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

private struct PlanCardView: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onTap: () -> Void

    private var trialText: String? {
        guard let intro = product.subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return nil }
        let value = intro.period.value
        let unit: String
        switch intro.period.unit {
        case .day:   unit = value == 1 ? "day" : "days"
        case .week:  unit = value == 1 ? "week" : "weeks"
        case .month: unit = value == 1 ? "month" : "months"
        case .year:  unit = value == 1 ? "year" : "years"
        @unknown default: unit = "days"
        }
        return "\(value)-\(unit) free trial"
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                    if let trial = trialText {
                        Text(trial)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppColor.accentGreen)
                    }
                }

                Spacer()

                if isBestValue {
                    Text("Best Value")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColor.accentGreen)
                        .cornerRadius(8)
                }

                Text(product.displayPrice)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? AppColor.accentBlue : AppColor.textPrimary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColor.accentBlue.opacity(0.08) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColor.accentBlue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
