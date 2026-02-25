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
                        Analytics.send("Game.completed", with: [
                            "labyrinthId": lab.id,
                            "difficulty": preferences.difficultyLevel.rawValue,
                            "itemsCollected": String(vm.collectedItemIndices.count),
                            "totalItems": String(vm.totalItemCount)
                        ])
                    })

                    NavigationControls(
                        currentIndex: gameViewModel.currentIndex,
                        total: gameViewModel.labyrinths.count,
                        onPrevious: {
                            ttsService.stop()
                            Analytics.send("Game.navigatedPrev", with: ["fromIndex": String(gameViewModel.currentIndex)])
                            gameViewModel.previousLabyrinth()
                            updateVM()
                        },
                        onNext: {
                            ttsService.stop()
                            Analytics.send("Game.navigatedNext", with: ["fromIndex": String(gameViewModel.currentIndex)])
                            attemptNext()
                        },
                        onReset: {
                            vm.reset()
                            Analytics.send("Game.reset", with: ["labyrinthId": lab.id])
                        },
                        onBack: {
                            ttsService.stop()
                            Analytics.send("Game.closed", with: [
                                "labyrinthId": lab.id,
                                "wasCompleted": String(showCompletion)
                            ])
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
                            Analytics.send("Completion.nextTapped", with: ["labyrinthId": lab.id])
                            attemptNext()
                        },
                        onRepeat: {
                            showCompletion = false
                            vm.reset()
                            Analytics.send("Completion.repeatTapped", with: ["labyrinthId": lab.id])
                        },
                        collectedCount: vm.collectedItemIndices.count,
                        totalItemCount: vm.totalItemCount
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
            Analytics.send("Paywall.shown", with: ["trigger": "game"])
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
            Analytics.send("Game.started", with: [
                "labyrinthId": lab.id,
                "difficulty": preferences.difficultyLevel.rawValue
            ])
            ttsService.prepareAudio(for: lab)
            if preferences.ttsEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    ttsService.playAudio(lab.audioInstruction)
                }
            }
        }
    }
}
