import SwiftUI
import StoreKit

// MARK: - OnboardingViewModel

/// Lightweight state model for onboarding page navigation.
/// Extracted to allow unit testing without SwiftUI environment.
final class OnboardingViewModel: ObservableObject {
    static let totalPages: Int = 5
    static let parentalGatePage: Int = 3

    enum NavigationResult: Equatable {
        case changed
        case blockedByParentalGate
        case unchanged
    }

    @Published var currentPage: Int = 0

    var isOnLastPage: Bool {
        currentPage == Self.totalPages - 1
    }

    var requiresParentalGateBeforeAdvance: Bool {
        currentPage == Self.parentalGatePage
    }

    func attemptAdvance() -> NavigationResult {
        attemptNavigate(to: currentPage + 1)
    }

    func attemptNavigate(to requestedPage: Int) -> NavigationResult {
        let clampedPage = min(max(requestedPage, 0), Self.totalPages - 1)

        guard clampedPage != currentPage else {
            return .unchanged
        }

        if currentPage == Self.parentalGatePage && clampedPage > currentPage {
            return .blockedByParentalGate
        }

        currentPage = clampedPage
        return .changed
    }

    func completeParentalGateAdvance() {
        currentPage = min(currentPage + 1, Self.totalPages - 1)
    }

    func completeParentalGateNavigation(to requestedPage: Int) {
        currentPage = min(max(requestedPage, 0), Self.totalPages - 1)
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var ttsService: TTSService

    var onComplete: (() -> Void)? = nil

    @StateObject private var viewModel = OnboardingViewModel()
    @State private var showParentalGate = false
    @State private var isPurchasing = false
    @State private var selectedProductId: String = "labyrinth_unlimited_lifetime1"
    @State private var tabSelection = 0
    @State private var pendingPageAfterGate: Int?
    @State private var tabViewResetToken = UUID()
    @State private var didPlayTutorialVoiceover = false

    private var currentPage: Int { viewModel.currentPage }
    private let totalPages = OnboardingViewModel.totalPages
    private var pageSelection: Binding<Int> {
        Binding(
            get: { tabSelection },
            set: { requestedPage in
                handleNavigationResult(
                    viewModel.attemptNavigate(to: requestedPage),
                    requestedPage: requestedPage
                )
            }
        )
    }

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
                TabView(selection: pageSelection) {
                    OnboardingPage1(
                        onComplete: advancePage,
                        onSkip: advancePage,
                        didPlayVoiceover: $didPlayTutorialVoiceover
                    )
                        .tag(0)
                    OnboardingPage2()
                        .tag(1)
                    OnboardingPage3()
                        .tag(2)
                    OnboardingPage4(onSelect: advancePage)
                    .tag(3)
                    OnboardingPage5(
                        selectedProductId: $selectedProductId,
                        isPurchasing: $isPurchasing,
                        onGetFullAccess: {
                            Analytics.send("Paywall.entryTapped", with: ["source": PaywallSource.onboarding.rawValue])
                            let product = subscriptionManager.products.first { $0.id == selectedProductId }
                                ?? subscriptionManager.products.last
                            guard let product else { return }
                            Task {
                                isPurchasing = true
                                Analytics.send("Paywall.purchaseAttempted", with: [
                                    "productId": product.id,
                                    "source": PaywallSource.onboarding.rawValue
                                ])
                                let success = await subscriptionManager.purchase(product)
                                isPurchasing = false
                                if success {
                                    Analytics.send("Paywall.purchaseSucceeded", with: [
                                        "productId": product.id,
                                        "source": PaywallSource.onboarding.rawValue
                                    ])
                                    completeOnboarding()
                                }
                            }
                        },
                        onStartFree: {
                            Analytics.send("Onboarding.startFreeTapped")
                            completeOnboarding()
                        },
                        onRestore: {
                            Analytics.send("Paywall.restoreTapped", with: ["source": PaywallSource.onboarding.rawValue])
                            Task { await subscriptionManager.restorePurchases() }
                        }
                    )
                    .tag(4)
                }
                .id(tabViewResetToken)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Next button (hidden on last page — it has its own CTAs)
                if !viewModel.isOnLastPage && currentPage != 0 {
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
                let destination = pendingPageAfterGate ?? min(viewModel.currentPage + 1, totalPages - 1)
                pendingPageAfterGate = nil
                showParentalGate = false
                withAnimation {
                    viewModel.completeParentalGateNavigation(to: destination)
                }
                tabSelection = viewModel.currentPage
            } onCancel: {
                pendingPageAfterGate = nil
                showParentalGate = false
                resetTabViewSelection()
            }
        }
        .onAppear {
            tabSelection = viewModel.currentPage
        }
        .onChange(of: viewModel.currentPage) { newValue in
            tabSelection = newValue
        }
        .task {
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
        }
    }

    private func advancePage() {
        let requestedPage = min(viewModel.currentPage + 1, totalPages - 1)
        handleNavigationResult(
            viewModel.attemptAdvance(),
            requestedPage: requestedPage
        )
    }

    private func handleNavigationResult(
        _ result: OnboardingViewModel.NavigationResult,
        requestedPage: Int
    ) {
        switch result {
        case .changed:
            showParentalGate = false
            tabSelection = viewModel.currentPage
        case .blockedByParentalGate:
            pendingPageAfterGate = min(max(requestedPage, 0), totalPages - 1)
            resetTabViewSelection()
            showParentalGate = true
        case .unchanged:
            resetTabViewSelection()
            break
        }
    }

    private func resetTabViewSelection() {
        tabSelection = viewModel.currentPage
        tabViewResetToken = UUID()
    }

    private func completeOnboarding() {
        Analytics.send("Onboarding.completed")
        preferences.hasCompletedOnboarding = true
        onComplete?()
    }
}

// MARK: - Screen 1: Draw the Path

private struct OnboardingPage1: View {
    @EnvironmentObject var ttsService: TTSService

    let onComplete: () -> Void
    let onSkip: () -> Void
    @Binding var didPlayVoiceover: Bool

    @StateObject private var tutorialViewModel = LabyrinthViewModel(
        labyrinth: onboardingTutorialLabyrinth,
        completionRadiusBase: 80
    )
    @State private var didAdvance = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 12)

            Text("Draw the Path")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)

            Text("Use your finger or Apple Pencil to trace the route.")
                .font(.system(size: 17, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            OnboardingTutorialMazeCard(viewModel: tutorialViewModel)
                .frame(maxWidth: 620)
                .frame(height: 360)
                .padding(.horizontal, 24)

            Spacer(minLength: 8)

            Button(action: {
                Analytics.send("Onboarding.tutorialSkipped")
                onSkip()
            }) {
                Text("Skip for Now")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .onAppear {
            tutorialViewModel.reset()
            Analytics.send("Onboarding.tutorialShown")
            guard !didPlayVoiceover else { return }
            didPlayVoiceover = true
            ttsService.playAudio("onboarding_trace_intro.mp3")
        }
        .onDisappear {
            ttsService.stop()
        }
        .onChange(of: tutorialViewModel.isCompleted) { completed in
            guard completed, !didAdvance else { return }
            didAdvance = true
            Analytics.send("Onboarding.tutorialCompleted")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onComplete()
                didAdvance = false
            }
        }
    }

}

private struct OnboardingTutorialMazeCard: View {
    @ObservedObject var viewModel: LabyrinthViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#DFF4FF") ?? .blue.opacity(0.18),
                                Color.white,
                                Color(hex: "#E9FFF4") ?? .green.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                ZStack {
                    OceanPatternView()
                        .opacity(0.08)

                    viewModel.mazePath
                        .stroke(
                            Color(hex: "#15A6C7") ?? .blue,
                            style: StrokeStyle(lineWidth: 16 * viewModel.scale, lineCap: .round, lineJoin: .round)
                        )

                    viewModel.mazePath
                        .stroke(
                            Color.white.opacity(0.95),
                            style: StrokeStyle(lineWidth: 10 * viewModel.scale, lineCap: .round, lineJoin: .round)
                        )

                    CharacterMarkerView(
                        character: viewModel.labyrinth.characterStart,
                        scale: max(viewModel.scale, 1.0),
                        isStart: true,
                        clipToCircle: true,
                        arrowAngle: viewModel.startArrowAngle
                    )
                    .position(viewModel.startPoint)

                    CharacterMarkerView(
                        character: viewModel.labyrinth.characterEnd,
                        scale: max(viewModel.scale, 1.0),
                        isStart: false,
                        clipToCircle: false
                    )
                    .position(viewModel.endPoint)

                    DrawingCanvas(viewModel: viewModel, tolerance: 1.0)

                }
                .padding(18)
            }
            .onAppear {
                viewModel.canvasSize = CGSize(width: geo.size.width - 36, height: geo.size.height - 36)
                viewModel.setupValidator(tolerance: 1.0)
            }
            .onChange(of: geo.size) { newSize in
                viewModel.canvasSize = CGSize(width: newSize.width - 36, height: newSize.height - 36)
                viewModel.setupValidator(tolerance: 1.0)
            }
        }
    }
}

private struct OnboardingStartHint: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.point.left.fill")
                .font(.system(size: 12, weight: .bold))
            Text("Start here")
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppColor.accentGreen)
        .cornerRadius(12)
        .scaleEffect(pulse ? 1.05 : 0.95)
        .shadow(color: AppColor.accentGreen.opacity(0.35), radius: pulse ? 10 : 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
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

            VStack(spacing: 14) {
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
    let onSelect: () -> Void

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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSelect() }
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

            // Legal links
            HStack(spacing: 4) {
                Link("Privacy Policy", destination: URL(string: "https://olgavorona.github.io/lowdop/privacy")!)
                Text("·")
                Link("Terms of Use", destination: URL(string: "https://olgavorona.github.io/lowdop/terms")!)
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundColor(AppColor.textTertiary)
            .padding(.bottom, 20)
        }
        .onAppear {
            Analytics.send("Paywall.shown", with: ["source": PaywallSource.onboarding.rawValue])
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

private let onboardingTutorialLabyrinth = Labyrinth(
    id: "onboarding_tutorial_easy",
    ageRange: "3-6",
    difficulty: "easy",
    theme: "ocean",
    title: "Draw the Path",
    storySetup: "Denny is ready to show how tracing works.",
    instruction: "Draw the path with your finger or Apple Pencil.",
    ttsInstruction: "Draw the path with your finger or Apple Pencil. Start at the green go marker.",
    characterStart: LabyrinthCharacter(
        type: "character",
        description: "Denny the crab at the start",
        position: "left",
        name: nil,
        imageAsset: "denny"
    ),
    characterEnd: LabyrinthCharacter(
        type: "character",
        description: "Finn cheering at the finish",
        position: "right",
        name: "Finn",
        imageAsset: "finn"
    ),
    educationalQuestion: "",
    funFact: "",
    completionMessage: "Nice work!",
    pathData: PathData(
        svgPath: "M 20 40 L 160 40 M 20 40 L 20 180 M 160 40 L 300 40 M 160 180 L 300 180 M 300 40 L 440 40 M 300 180 L 440 180 M 440 40 L 580 40 M 580 40 L 580 180 M 20 320 L 160 320 M 20 180 L 20 320 M 160 180 L 300 180 M 300 180 L 300 320 M 300 180 L 440 180 M 300 180 L 300 320 M 580 180 L 580 320 M 20 320 L 160 320 M 20 460 L 160 460 M 20 320 L 20 460 M 160 460 L 300 460 M 440 320 L 440 460 M 300 460 L 440 460 M 580 320 L 580 460 M 440 460 L 580 460 M 440 320 L 440 460",
        solutionPath: "M 90 390 L 230 390 L 370 390 L 370 250 L 510 250 L 510 110",
        width: 40,
        complexity: "easy",
        mazeType: "grid",
        startPoint: PointData(x: 90, y: 390),
        endPoint: PointData(x: 510, y: 110),
        segments: [
            SegmentData(start: PointData(x: 90, y: 110), end: PointData(x: 230, y: 110)),
            SegmentData(start: PointData(x: 90, y: 110), end: PointData(x: 90, y: 250)),
            SegmentData(start: PointData(x: 230, y: 110), end: PointData(x: 370, y: 110)),
            SegmentData(start: PointData(x: 370, y: 110), end: PointData(x: 510, y: 110)),
            SegmentData(start: PointData(x: 510, y: 110), end: PointData(x: 510, y: 250)),
            SegmentData(start: PointData(x: 90, y: 250), end: PointData(x: 230, y: 250)),
            SegmentData(start: PointData(x: 230, y: 250), end: PointData(x: 230, y: 390)),
            SegmentData(start: PointData(x: 370, y: 250), end: PointData(x: 510, y: 250)),
            SegmentData(start: PointData(x: 370, y: 250), end: PointData(x: 370, y: 390)),
            SegmentData(start: PointData(x: 510, y: 250), end: PointData(x: 510, y: 390)),
            SegmentData(start: PointData(x: 90, y: 390), end: PointData(x: 230, y: 390)),
            SegmentData(start: PointData(x: 230, y: 390), end: PointData(x: 370, y: 390)),
        ],
        canvasWidth: 600,
        canvasHeight: 500,
        controlPoints: [],
        items: nil,
        avoidItems: nil
    ),
    visualTheme: VisualTheme(
        backgroundColor: "#6CCFF6",
        decorativeElements: ["waves", "bubbles"]
    ),
    location: "Tutorial Reef",
    audioInstruction: nil,
    audioCompletion: nil,
    itemRule: nil,
    itemEmoji: nil
)

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
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .padding(6)
                    }
                }

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
