import SwiftUI

// MARK: - OnboardingViewModel

final class OnboardingViewModel: ObservableObject {
    static let totalPages: Int = 3

    @Published var currentPage: Int = 0

    var isOnLastPage: Bool {
        currentPage == Self.totalPages - 1
    }

    enum NavigationResult: Equatable {
        case changed
        case unchanged
    }

    func attemptAdvance() -> NavigationResult {
        attemptNavigate(to: currentPage + 1)
    }

    func attemptNavigate(to requestedPage: Int) -> NavigationResult {
        let clampedPage = min(max(requestedPage, 0), Self.totalPages - 1)
        guard clampedPage != currentPage else { return .unchanged }
        currentPage = clampedPage
        return .changed
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService

    var onComplete: (() -> Void)? = nil

    @StateObject private var viewModel = OnboardingViewModel()
    @State private var tabSelection = 0
    @State private var didPlayTutorialVoiceover = false

    private var currentPage: Int { viewModel.currentPage }
    private let totalPages = OnboardingViewModel.totalPages

    private var pageSelection: Binding<Int> {
        Binding(
            get: { tabSelection },
            set: { requestedPage in
                _ = viewModel.attemptNavigate(to: requestedPage)
                tabSelection = viewModel.currentPage
            }
        )
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
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

                TabView(selection: pageSelection) {
                    OnboardingPage1(
                        onComplete: advancePage,
                        onSkip: advancePage,
                        didPlayVoiceover: $didPlayTutorialVoiceover
                    )
                    .tag(0)

                    OnboardingPage2()
                        .tag(1)

                    OnboardingPage3(onStart: completeOnboarding)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

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
        .onAppear { tabSelection = viewModel.currentPage }
        .onChange(of: viewModel.currentPage) { newValue in tabSelection = newValue }
    }

    private func advancePage() {
        _ = viewModel.attemptAdvance()
        tabSelection = viewModel.currentPage
    }

    private func completeOnboarding() {
        Analytics.send("Onboarding.completed")
        preferences.hasCompletedOnboarding = true
        onComplete?()
    }
}

// MARK: - Page 1: Trace the Path (tutorial maze)

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

            Text("Trace the Path")
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
        .onDisappear { ttsService.stop() }
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

// MARK: - Page 2: Features

private struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Practice Every Day")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.bottom, 12)

            VStack(spacing: 14) {
                OnboardingFeatureRow(icon: "textformat.abc", label: "Letters, numbers, and shapes")
                OnboardingFeatureRow(icon: "pencil.tip", label: "Trace with finger or Apple Pencil")
                OnboardingFeatureRow(icon: "checkmark.circle.fill", label: "No ads, no pressure, works offline")
            }
            .padding(.horizontal, 48)

            Spacer()
        }
    }
}

// MARK: - Page 3: Let's Start

private struct OnboardingPage3: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Ready to Trace?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .padding(.bottom, 8)

            Text("Pick a book from the shelf and start tracing!")
                .font(.system(size: 17, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

            Button(action: onStart) {
                Text("Let's Go!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColor.accentGreen)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)

            HStack(spacing: 4) {
                Link("Privacy Policy", destination: URL(string: "https://olgavorona.github.io/lowdop/privacy")!)
                Text("·")
                Link("Terms of Use", destination: URL(string: "https://olgavorona.github.io/lowdop/terms")!)
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundColor(AppColor.textTertiary)
            .padding(.top, 16)
            .padding(.bottom, 24)

            Spacer()
        }
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

// MARK: - Tutorial labyrinth

private let onboardingTutorialLabyrinth = Labyrinth(
    id: "onboarding_tutorial_easy",
    ageRange: "3-6",
    difficulty: "easy",
    theme: "ocean",
    title: "Trace the Path",
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
