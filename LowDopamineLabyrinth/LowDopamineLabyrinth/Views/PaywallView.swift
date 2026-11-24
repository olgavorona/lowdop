import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var reviewRequestManager: ReviewRequestManager
    @EnvironmentObject var preferences: UserPreferences
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
            paywallContent
            dismissButton
        }
        .environment(\.locale, preferences.appLanguage.locale)
        .environment(\.layoutDirection, preferences.appLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
        .task {
            await subscriptionManager.loadProducts()
            trackViewIfNeeded()
        }
        .onAppear {
            trackViewIfNeeded()
        }
    }

    private var paywallContent: some View {
        PaywallLayout {
            PaywallHero(title: variant.title, subtitle: variant.body)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(benefits, id: \.self) { benefit in
                    PaywallBenefitRow(message: benefit)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 24)
        } offer: {
            if let product {
                LifetimePaywallCard(
                    product: product,
                    title: variant == .discount ? "Special unlock price" : "Forever access",
                    originalPrice: variant == .discount ? subscriptionManager.regularFullAccessProduct?.displayPrice : nil
                )
            } else {
                ProgressView().frame(height: 90)
            }
        } actions: {
            Button(action: executePurchase) {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(LocalizedStringKey(ctaTitle))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
            }
            .buttonStyle(PaywallPrimaryButtonStyle())
            .disabled(isPurchasing || product == nil)
            .opacity((isPurchasing || product == nil) ? 0.6 : 1)
            .accessibilityIdentifier("paywall.purchase")

            Text(LocalizedStringKey(variant.supportingLine))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppColor.textTertiary)
                .multilineTextAlignment(.center)

            Button(action: dismissWithoutPurchase) {
                Text(LocalizedStringKey(variant.secondaryActionTitle))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppColor.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.plain)
        } footer: {
            HStack(spacing: 20) {
                Link("Privacy", destination: URL(string: "https://olgavorona.github.io/lowdop/privacy")!)
                Link("Terms", destination: URL(string: "https://olgavorona.github.io/lowdop/terms")!)
                Button(action: {
                    Task { await subscriptionManager.restorePurchases() }
                }) {
                    Text("Restore Purchases")
                }
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(AppColor.textTertiary)
            .frame(minHeight: 44)
        }
    }

    private var dismissButton: some View {
        Button(action: dismissWithoutPurchase) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColor.textSecondary)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.9))
                .clipShape(Circle())
        }
        .accessibilityLabel("Close")
        .accessibilityIdentifier("paywall.close")
        .padding(16)
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
                reviewRequestManager.requestAfterSuccessfulPurchase(
                    isPremium: subscriptionManager.isPremium
                )
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
            "paywall_type": variant.rawValue,
            "difficulty": preferences.difficultyLevel.rawValue,
            "app_locale": preferences.appLanguage.rawValue
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

// MARK: - Shared paywall presentation

struct PaywallLayout<Intro: View, Offer: View, Actions: View, Footer: View>: View {
    let intro: Intro
    let offer: Offer
    let actions: Actions
    let footer: Footer

    init(@ViewBuilder intro: () -> Intro, @ViewBuilder offer: () -> Offer,
         @ViewBuilder actions: () -> Actions, @ViewBuilder footer: () -> Footer) {
        self.intro = intro()
        self.offer = offer()
        self.actions = actions()
        self.footer = footer()
    }

    var body: some View {
        GeometryReader { geometry in
            if UIDevice.current.userInterfaceIdiom == .pad {
                tabletPresentation(size: geometry.size)
            } else if geometry.size.width > geometry.size.height {
                columns
            } else {
                portrait
            }
        }
        .background(AppColor.background)
    }

    private var portrait: some View {
        VStack(spacing: 0) {
            GeometryReader { contentGeometry in
                ScrollView {
                    VStack(spacing: 0) { intro }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, minHeight: contentGeometry.size.height, alignment: .top)
                }
            }
            offer
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            VStack(spacing: 12) { actions }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            VStack(spacing: 0) { footer }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 540 : 460)
        .frame(maxWidth: .infinity)
    }

    private var columns: some View {
        GeometryReader { geometry in
            HStack(spacing: 32) {
                ScrollView {
                    VStack(spacing: 0) { intro }
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .frame(maxWidth: .infinity)
                ScrollView {
                    VStack(spacing: 16) {
                        offer
                        VStack(spacing: 10) { actions }
                        VStack(spacing: 0) { footer }
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
        }
    }

    private func tabletPresentation(size: CGSize) -> some View {
        Group {
            if size.width > size.height && size.width >= 760 {
                columns
                    .padding(24)
                    .frame(width: max(0, min(940, size.width - 64)), height: max(0, min(620, size.height - 64)))
            } else if size.width >= 540 && size.height < 800 {
                columns
                    .padding(.vertical, 12)
                    .frame(width: max(0, size.width - 32), height: max(0, size.height - 32))
            } else {
                portrait
                    .padding(.vertical, 12)
                    .frame(width: max(0, min(540, size.width - 48)), height: max(0, min(760, size.height - 64)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white.opacity(0.9))
                .shadow(color: AppColor.textPrimary.opacity(0.08), radius: 24, x: 0, y: 12)
        }
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(AppColor.textFaint.opacity(0.2), lineWidth: 1))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PaywallHero: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image("denny")
                .resizable()
                .scaledToFill()
                .frame(width: 164, height: 116)
                .clipped()
                .accessibilityHidden(true)
            Text(LocalizedStringKey(title))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(LocalizedStringKey(subtitle))
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PaywallBenefitRow: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundColor(AppColor.endMarkerGreen)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(message))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LifetimePaywallCard: View {
    let product: Product
    var title: String = "Forever access"
    var originalPrice: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("One-time purchase")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                if let originalPrice {
                    Text(originalPrice)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppColor.textTertiary)
                        .strikethrough()
                }
                Text(product.displayPrice)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 90)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(AppColor.accentGreen.opacity(0.14))
                .shadow(color: AppColor.accentGreen.opacity(0.25), radius: 0, x: 0, y: 4)
        }
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppColor.accentGreen, lineWidth: 1.5))
        .accessibilityIdentifier("paywall.planCard")
    }
}

struct PaywallPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "#2E8B50")!)
                    .shadow(color: AppColor.endMarkerGreen.opacity(0.25), radius: 0, x: 0, y: 4)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
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
                "Forever access"
            ]
        case .discount:
            return [
                "Unlock all mazes",
                "Works offline",
                "Forever access"
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
