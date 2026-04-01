import SwiftUI
import StoreKit

// MARK: - OnboardingViewModel

/// Lightweight state model for onboarding page navigation.
/// Extracted to allow unit testing without SwiftUI environment.
final class OnboardingViewModel: ObservableObject {
    static let totalPages: Int = 4

    @Published var currentPage: Int = 0

    var isOnLastPage: Bool {
        currentPage == Self.totalPages - 1
    }

    func advance() {
        currentPage = min(currentPage + 1, Self.totalPages - 1)
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    /// Called when onboarding completes (any exit path).
    var onComplete: (() -> Void)? = nil

    @StateObject private var viewModel = OnboardingViewModel()
    @State private var showParentalGate = false
    @State private var pendingProduct: Product? = nil
    @State private var isPurchasing = false
    @State private var selectedProductId: String = "labyrinth_unlimited_lifetime1"

    private var currentPage: Int { viewModel.currentPage }
    private let totalPages = OnboardingViewModel.totalPages

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? AppColor.accentGreen : AppColor.textFaint)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 8)

                // Pages
                TabView(selection: $viewModel.currentPage) {
                    OnboardingPage1()
                        .tag(0)
                    OnboardingPage2()
                        .tag(1)
                    OnboardingPage3()
                        .tag(2)
                    OnboardingPage4(
                        selectedProductId: $selectedProductId,
                        isPurchasing: $isPurchasing,
                        onPlanTap: { product in
                            pendingProduct = product
                            showParentalGate = true
                        },
                        onStartFree: completeOnboarding,
                        onRestore: {
                            Task { await subscriptionManager.restorePurchases() }
                        }
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Next button (hidden on last page — page 4 has its own CTA)
                if !viewModel.isOnLastPage {
                    Button(action: advancePage) {
                        Text("Next")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppColor.accentGreen)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 28)
                    .transition(.opacity)
                }
            }
        }
        .fullScreenCover(isPresented: $showParentalGate) {
            if let product = pendingProduct {
                ParentalGateView(purpose: .paywall) {
                    // Success: parental gate passed → purchase
                    showParentalGate = false
                    Task {
                        isPurchasing = true
                        let success = await subscriptionManager.purchase(product)
                        isPurchasing = false
                        if success { completeOnboarding() }
                    }
                } onCancel: {
                    showParentalGate = false
                }
            }
        }
        .task {
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
        }
    }

    private func advancePage() {
        withAnimation {
            viewModel.advance()
        }
    }

    private func completeOnboarding() {
        Analytics.send("Onboarding.completed")
        preferences.hasCompletedOnboarding = true
        onComplete?()
    }
}

// MARK: - Screen 1: How to Play

private struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColor.accentGreen.opacity(0.12))
                    .frame(width: 220, height: 220)

                if UIImage(named: "onboarding_draw") != nil {
                    Image("onboarding_draw")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .cornerRadius(16)
                } else {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 72))
                        .foregroundColor(AppColor.accentGreen)
                }
            }
            .padding(.bottom, 32)

            Text("Draw the Path")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.bottom, 12)

            Text("Use your finger or Apple Pencil\nto trace the route")
                .font(.system(size: 17, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Screen 2: Calm & Focused

private struct OnboardingPage2: View {
    private let features: [(icon: String, label: String)] = [
        ("checkmark.circle", "No ads, ever"),
        ("checkmark.circle", "No timers or pressure"),
        ("checkmark.circle", "Works offline")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Maze screenshot or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColor.accentBlue.opacity(0.10))
                    .frame(width: 240, height: 160)

                if UIImage(named: "onboarding_maze_screenshot") != nil {
                    Image("onboarding_maze_screenshot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 160)
                        .cornerRadius(16)
                        .clipped()
                } else {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(AppColor.accentBlue)
                }
            }
            .padding(.bottom, 28)

            Text("Calm & Focused")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.bottom, 8)

            Text("No flashing animations. No distractions.\nJust quiet focus.")
                .font(.system(size: 17, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(features, id: \.label) { feature in
                    HStack(spacing: 10) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 18))
                            .foregroundColor(AppColor.accentGreen)
                        Text(feature.label)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(AppColor.textPrimary)
                    }
                }
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Screen 3: Difficulty

private struct OnboardingPage3: View {
    @EnvironmentObject var preferences: UserPreferences

    private let levelColors: [DifficultyLevel: [Color]] = [
        .easy: [Color(hex: "#81C784") ?? .green, Color(hex: "#66BB6A") ?? .green],
        .medium: [Color(hex: "#FFB74D") ?? .orange, Color(hex: "#FFA726") ?? .orange],
        .hard: [Color(hex: "#EF5350") ?? .red, Color(hex: "#E53935") ?? .red]
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Set the Difficulty")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.bottom, 10)

            Text("Choose what feels right for your child")
                .font(.system(size: 17, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .padding(.bottom, 32)

            HStack(spacing: 16) {
                ForEach(DifficultyLevel.allCases, id: \.self) { level in
                    OnboardingDifficultyButton(
                        level: level,
                        colors: levelColors[level] ?? [.blue, .blue],
                        isSelected: preferences.difficultyLevel == level
                    ) {
                        preferences.difficultyLevel = level
                        Analytics.send("Onboarding.difficultySelected", with: ["level": level.rawValue])
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

private struct OnboardingDifficultyButton: View {
    let level: DifficultyLevel
    let colors: [Color]
    let isSelected: Bool
    let action: () -> Void

    private var levelNumber: Int {
        switch level {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .opacity(isSelected ? 1.0 : 0.55)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 80)

                Text(level.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? AppColor.textPrimary : AppColor.textSecondary)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < levelNumber ? colors[0] : Color.gray.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppColor.accentGreen.opacity(0.08) : Color.white)
                    .shadow(color: isSelected ? AppColor.accentGreen.opacity(0.25) : Color.black.opacity(0.05), radius: 6, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColor.accentGreen : Color.gray.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Screen 4: Soft Paywall

private struct OnboardingPage4: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var selectedProductId: String
    @Binding var isPurchasing: Bool
    let onPlanTap: (Product) -> Void
    let onStartFree: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Ready to Explore?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.bottom, 8)

            Text("First 3 mazes are free.\nUnlock everything for your child.")
                .font(.system(size: 17, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 24)

            // Plan cards
            if subscriptionManager.products.isEmpty {
                ProgressView()
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(subscriptionManager.products, id: \.id) { product in
                        OnboardingPlanCard(
                            product: product,
                            isSelected: selectedProductId == product.id,
                            isBestValue: product.id == "labyrinth_unlimited_lifetime1"
                        ) {
                            selectedProductId = product.id
                            onPlanTap(product)
                        }
                    }
                }
                .padding(.horizontal, 32)
            }

            Spacer(minLength: 20)

            // Primary CTA
            Button(action: onStartFree) {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Start for Free →")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .background(AppColor.accentGreen)
            .cornerRadius(14)
            .disabled(isPurchasing)
            .opacity(isPurchasing ? 0.6 : 1.0)
            .padding(.horizontal, 32)
            .padding(.bottom, 12)

            // Restore link
            Button(action: onRestore) {
                Text("Restore Purchases")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppColor.textTertiary)
            }
            .frame(height: 36)
            .padding(.bottom, 20)
        }
    }
}

private struct OnboardingPlanCard: View {
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

// MARK: - DifficultyCard (legacy, kept for compatibility)

struct DifficultyCard: View {
    let level: DifficultyLevel
    let colors: [Color]
    let samplePath: String
    let action: () -> Void

    private var levelNumber: Int {
        switch level {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    if !samplePath.isEmpty {
                        GeometryReader { geo in
                            let scale = min(geo.size.width, geo.size.height) / 600
                            SVGPathParser.parse(samplePath, scale: scale)
                                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                        }
                        .padding(8)
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)

                Text(level.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < levelNumber ? colors[0] : Color.gray.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
