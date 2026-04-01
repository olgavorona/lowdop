import SwiftUI
import StoreKit

// MARK: - OnboardingViewModel

/// Lightweight state model for onboarding page navigation.
/// Extracted to allow unit testing without SwiftUI environment.
final class OnboardingViewModel: ObservableObject {
    static let totalPages: Int = 5

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
                    OnboardingPage4()
                        .tag(3)
                    OnboardingPage5(
                        selectedProductId: $selectedProductId,
                        isPurchasing: $isPurchasing,
                        onGetFullAccess: {
                            let product = subscriptionManager.products.first { $0.id == selectedProductId }
                                ?? subscriptionManager.products.last
                            pendingProduct = product
                            showParentalGate = true
                        },
                        onStartFree: completeOnboarding,
                        onRestore: {
                            Task { await subscriptionManager.restorePurchases() }
                        }
                    )
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Next button (hidden on last page — it has its own CTAs)
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
            ParentalGateView(purpose: .paywall) {
                showParentalGate = false
                guard let product = pendingProduct else { return }
                Task {
                    isPurchasing = true
                    let success = await subscriptionManager.purchase(product)
                    isPurchasing = false
                    if success { completeOnboarding() }
                }
            } onCancel: {
                showParentalGate = false
                pendingProduct = nil
            }
        }
        .task {
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
        }
    }

    private func advancePage() {
        withAnimation { viewModel.advance() }
    }

    private func completeOnboarding() {
        Analytics.send("Onboarding.completed")
        preferences.hasCompletedOnboarding = true
        onComplete?()
    }
}

// MARK: - Screen 1: Draw the Path

private struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            bundleImage("onboarding_draw")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 500)
                .cornerRadius(20)
                .padding(.horizontal, 32)
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

// MARK: - Screen 2: 100 Labyrinths

private struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("100+")
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundColor(AppColor.accentGreen)

            Text("Labyrinths to Explore")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.bottom, 12)

            Text("New adventures added every month")
                .font(.system(size: 17, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .padding(.bottom, 36)

            VStack(spacing: 14) {
                OnboardingFeatureRow(icon: "map.fill",       label: "10 unique ocean stories")
                OnboardingFeatureRow(icon: "dial.low.fill",  label: "3 difficulty levels for every child")
                OnboardingFeatureRow(icon: "star.fill",      label: "Collect treasures along the way")
                OnboardingFeatureRow(icon: "arrow.clockwise",label: "New content added regularly")
            }
            .padding(.horizontal, 48)

            Spacer()
        }
    }
}

// MARK: - Screen 3: Calm & Focused

private struct OnboardingPage3: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            bundleImage("onboarding_maze_screenshot")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 420)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                .padding(.horizontal, 32)
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

            VStack(spacing: 12) {
                OnboardingFeatureRow(icon: "checkmark.circle.fill", label: "No ads, ever")
                OnboardingFeatureRow(icon: "checkmark.circle.fill", label: "No timers or pressure")
                OnboardingFeatureRow(icon: "checkmark.circle.fill", label: "Works offline")
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Screen 4: Difficulty

private struct OnboardingPage4: View {
    @EnvironmentObject var preferences: UserPreferences

    private let levelColors: [DifficultyLevel: [Color]] = [
        .easy:   [Color(hex: "#4FC3F7") ?? .blue,   Color(hex: "#29B6F6") ?? .blue],
        .medium: [Color(hex: "#29B6F6") ?? .blue,   Color(hex: "#039BE5") ?? .blue],
        .hard:   [Color(hex: "#039BE5") ?? .blue,   Color(hex: "#0277BD") ?? .blue],
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

            HStack(spacing: 12) {
                ForEach(DifficultyLevel.allCases, id: \.self) { level in
                    DifficultyCard(
                        level: level,
                        colors: levelColors[level] ?? [.blue, .blue],
                        samplePath: loadSamplePath(for: level),
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

    private func loadSamplePath(for level: DifficultyLevel) -> String {
        guard let url = Bundle.main.url(forResource: "difficulty_samples", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let samples = try? JSONDecoder().decode([String: String].self, from: data) else {
            return ""
        }
        return samples[level.rawValue] ?? ""
    }
}

// MARK: - Screen 5: Soft Paywall

private struct OnboardingPage5: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var selectedProductId: String
    @Binding var isPurchasing: Bool
    let onGetFullAccess: () -> Void
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

            // Plan cards — tap to select only
            if subscriptionManager.products.isEmpty {
                ProgressView().padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(subscriptionManager.products, id: \.id) { product in
                        OnboardingPlanCard(
                            product: product,
                            isSelected: selectedProductId == product.id,
                            isBestValue: product.id == "labyrinth_unlimited_lifetime1"
                        ) {
                            selectedProductId = product.id
                        }
                    }
                }
                .padding(.horizontal, 32)
            }

            Spacer(minLength: 20)

            // Get Full Access (primary — purchases selected plan)
            Button(action: onGetFullAccess) {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Get Full Access")
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
            .padding(.bottom, 10)

            // Start for Free (secondary)
            Button(action: onStartFree) {
                Text("Start for Free →")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 10)

            // Restore Purchases (tertiary)
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

// MARK: - Plan Card

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
        case .day:   unit = value == 1 ? "day"   : "days"
        case .week:  unit = value == 1 ? "week"  : "weeks"
        case .month: unit = value == 1 ? "month" : "months"
        case .year:  unit = value == 1 ? "year"  : "years"
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
                    .stroke(isSelected ? AppColor.accentBlue : Color.gray.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared helpers

private struct OnboardingFeatureRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColor.accentGreen)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
            Spacer()
        }
    }
}

/// Load a PNG from the app bundle (Resources/, not .xcassets).
private func bundleImage(_ name: String) -> Image {
    if let path = Bundle.main.path(forResource: name, ofType: "png"),
       let ui = UIImage(contentsOfFile: path) {
        return Image(uiImage: ui)
    }
    return Image(systemName: "photo")
}

// MARK: - DifficultyCard (used by LabyrinthGridView + OnboardingPage4)

struct DifficultyCard: View {
    let level: DifficultyLevel
    let colors: [Color]
    let samplePath: String
    var isSelected: Bool = false
    let action: () -> Void

    private var levelNumber: Int {
        switch level {
        case .easy:   return 1
        case .medium: return 2
        case .hard:   return 3
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )

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
        .buttonStyle(.plain)
    }
}
