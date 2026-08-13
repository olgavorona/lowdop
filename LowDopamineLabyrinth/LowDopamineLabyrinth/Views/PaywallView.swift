import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    let source: PaywallSource
    var onDismissWithoutPurchase: (() -> Void)? = nil
    @State private var isPurchasing = false
    @State private var didTrackView = false

    private var variant: PaywallVariant {
        subscriptionManager.isDiscountEligible ? .discount : .regular
    }

    private var product: Product? {
        switch variant {
        case .regular:
            return subscriptionManager.regularFullAccessProduct
        case .discount:
            return subscriptionManager.discountFullAccessProduct
        }
    }

    private var benefits: [String] { variant.benefits }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
            // MARK: - Left Column: Hero + Benefits
                VStack(spacing: 16) {
                    Spacer()

                    Image("denny")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)

                    Text(variant.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(variant.body)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

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

            // MARK: - Right Column: Purchase + CTA
                VStack(spacing: 12) {
                    Spacer()

                    if let product {
                        PlanCardView(
                            variant: variant,
                            product: product,
                            regularProduct: subscriptionManager.regularFullAccessProduct
                        )
                    } else {
                        ProgressView()
                            .padding()
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
                                    .minimumScaleFactor(0.78)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .background(AppColor.accentBlue)
                    .cornerRadius(14)
                    .disabled(isPurchasing || product == nil)
                    .opacity(isPurchasing ? 0.6 : 1.0)
                    .padding(.top, 4)

                    Text(variant.supportingLine)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppColor.textTertiary)
                        .multilineTextAlignment(.center)

                    Button(action: dismissWithoutPurchase) {
                        Text(variant.secondaryActionTitle)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppColor.textTertiary)
                    }
                    .frame(height: 36)

                    Button(action: {
                        Task { await subscriptionManager.restorePurchases() }
                    }) {
                        Text("Restore Purchases")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(AppColor.textTertiary)
                    }
                    .frame(height: 30)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            }
            .background(AppColor.background)

            Button(action: dismissWithoutPurchase) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColor.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")
            .padding(16)
        }
        .task {
            await subscriptionManager.loadProducts()
            trackViewIfNeeded()
        }
        .onAppear {
            trackViewIfNeeded()
        }
    }

    private var ctaTitle: String {
        product == nil ? "Loading..." : "Unlock Everything"
    }

    private func executePurchase() {
        guard let product else { return }
        Analytics.send(variant.purchaseStartedEvent, with: analyticsProperties(for: product))
        Task {
            isPurchasing = true
            let success = await subscriptionManager.purchase(product)
            isPurchasing = false
            if success {
                Analytics.send(variant.purchaseSuccessEvent, with: analyticsProperties(for: product))
                dismiss()
            } else {
                Analytics.send(variant.purchaseCancelledEvent, with: analyticsProperties(for: product))
            }
        }
    }

    private func dismissWithoutPurchase() {
        Analytics.send(variant.dismissedEvent, with: [
            "source": source.rawValue,
            "paywall_type": variant.rawValue
        ])
        onDismissWithoutPurchase?()
        dismiss()
    }

    private func analyticsProperties(for product: Product) -> [String: String] {
        [
            "product_id": product.id,
            "localized_price": product.displayPrice,
            "currency": product.priceFormatStyle.currencyCode,
            "source": source.rawValue,
            "paywall_type": variant.rawValue
        ]
    }

    private func trackViewIfNeeded() {
        guard !didTrackView else { return }
        if product == nil && subscriptionManager.products.isEmpty { return }
        didTrackView = true
        subscriptionManager.markInitialPaywallSeen()
        if let product {
            Analytics.send(variant.shownEvent, with: analyticsProperties(for: product))
        } else {
            Analytics.send(variant.shownEvent, with: [
                "source": source.rawValue,
                "paywall_type": variant.rawValue
            ])
        }
    }
}

private enum PaywallVariant: String {
    case regular
    case discount

    var title: String {
        switch self {
        case .regular: return "Unlock all of Denny's Maze"
        case .discount: return "Keep exploring with Denny"
        }
    }

    var body: String {
        switch self {
        case .regular:
            return "Get every maze and difficulty level with one simple purchase."
        case .discount:
            return "Unlock every maze with one purchase."
        }
    }

    var benefits: [String] {
        switch self {
        case .regular:
            return [
                "All mazes and difficulty levels",
                "Works completely offline",
                "No ads",
                "No subscription"
            ]
        case .discount:
            return [
                "Unlock all mazes",
                "All difficulty levels",
                "Works offline",
                "No ads",
                "No subscription"
            ]
        }
    }

    var supportingLine: String {
        switch self {
        case .regular:
            return "One-time purchase. Yours forever."
        case .discount:
            return "One-time purchase. No recurring charges."
        }
    }

    var secondaryActionTitle: String {
        switch self {
        case .regular:
            return "Not now"
        case .discount:
            return "Not now"
        }
    }

    var shownEvent: String {
        switch self {
        case .regular: return "initial_paywall_view"
        case .discount: return "discount_paywall_view"
        }
    }

    var purchaseStartedEvent: String {
        switch self {
        case .regular: return "initial_paywall_purchase_started"
        case .discount: return "discount_purchase_started"
        }
    }

    var purchaseSuccessEvent: String {
        switch self {
        case .regular: return "initial_paywall_purchase_success"
        case .discount: return "discount_purchase_success"
        }
    }

    var purchaseCancelledEvent: String {
        switch self {
        case .regular: return "initial_paywall_purchase_cancelled"
        case .discount: return "discount_purchase_cancelled"
        }
    }

    var dismissedEvent: String {
        switch self {
        case .regular: return "initial_paywall_dismissed"
        case .discount: return "discount_paywall_dismissed"
        }
    }
}

private struct PlanCardView: View {
    let variant: PaywallVariant
    let product: Product
    let regularProduct: Product?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(variant == .discount ? "Special unlock price" : product.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)

                Text("One-time purchase")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppColor.accentGreen)
            }

            Spacer()

            if variant == .discount {
                VStack(alignment: .trailing, spacing: 3) {
                    if let regularProduct {
                        Text(regularProduct.displayPrice)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColor.textTertiary)
                            .strikethrough(true, color: AppColor.textTertiary)
                    }
                    Text(product.displayPrice)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(AppColor.accentBlue)
                }
            } else {
                Text(product.displayPrice)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.accentBlue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColor.accentBlue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColor.accentBlue, lineWidth: 2)
        )
    }
}
