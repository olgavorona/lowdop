import SwiftUI

struct LabyrinthListView: View {
    @EnvironmentObject var gameViewModel: GameViewModel
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService
    @State private var showCompletion = false
    @State private var showPaywall = false
    @State private var paywallSkipped = false
    @State private var labyrinthVM: LabyrinthViewModel?

    var body: some View {
        ZStack {
            if let lab = gameViewModel.currentLabyrinth {
                let vm = labyrinthVM ?? makeVM(for: lab)

                VStack(spacing: 0) {
                    LabyrinthGameView(viewModel: vm, onComplete: {
                        gameViewModel.completeCurrentLabyrinth()
                        showCompletion = true
                    })

                    NavigationControls(
                        currentIndex: gameViewModel.currentIndex,
                        total: gameViewModel.labyrinths.count,
                        onPrevious: {
                            ttsService.stop()
                            gameViewModel.previousLabyrinth()
                            updateVM()
                        },
                        onNext: {
                            ttsService.stop()
                            attemptNext()
                        },
                        onReset: {
                            vm.reset()
                        },
                        onBack: {
                            ttsService.stop()
                            gameViewModel.closeGame()
                        },
                        ttsEnabled: $preferences.ttsEnabled
                    )
                    .background(vm.backgroundColor.opacity(0.8))
                }
                .ignoresSafeArea(.container, edges: .bottom)

                if showCompletion {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { }

                    CompletionView(
                        labyrinth: lab,
                        onNext: {
                            showCompletion = false
                            ttsService.stop()
                            attemptNext()
                        },
                        onRepeat: {
                            showCompletion = false
                            vm.reset()
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            } else {
                VStack {
                    Text("No labyrinths available")
                        .font(.system(size: 18, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            updateVM()
        }
        .animation(.easeInOut(duration: 0.3), value: showCompletion)
        .sheet(isPresented: $showPaywall, onDismiss: {
            if gameViewModel.isPremium || paywallSkipped {
                // Purchased or skipped: advance to next labyrinth
                paywallSkipped = false
                gameViewModel.nextLabyrinth()
                updateVM()
            } else {
                // "Maybe Later": go back to main grid
                ttsService.stop()
                gameViewModel.closeGame()
            }
        }) {
            PaywallView(onSkip: { paywallSkipped = true })
        }
    }

    private func attemptNext() {
        if gameViewModel.canProceed() {
            gameViewModel.nextLabyrinth()
            updateVM()
        } else {
            showPaywall = true
        }
    }

    private func makeVM(for lab: Labyrinth) -> LabyrinthViewModel {
        let vm = LabyrinthViewModel(labyrinth: lab)
        DispatchQueue.main.async { self.labyrinthVM = vm }
        return vm
    }

    private func updateVM() {
        showCompletion = false
        if let lab = gameViewModel.currentLabyrinth {
            let oldCanvas = labyrinthVM?.canvasSize ?? .zero
            let newVM = LabyrinthViewModel(labyrinth: lab)
            newVM.canvasSize = oldCanvas
            if oldCanvas != .zero {
                newVM.setupValidator(tolerance: preferences.pathTolerance)
            }
            labyrinthVM = newVM
            ttsService.prepareAudio(for: lab)
            if preferences.ttsEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    ttsService.playAudio(lab.audioInstruction)
                }
            }
        }
    }
}
