import SwiftUI

struct LabyrinthListView: View {
    @EnvironmentObject var gameViewModel: GameViewModel
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showCompletion = false
    @State private var isStoryComplete = false
    @State private var showParentalGate = false
    @State private var showPaywall = false
    @State private var labyrinthVM: LabyrinthViewModel?

    var body: some View {
        ZStack {
            if let lab = gameViewModel.currentLabyrinth {
                let vm = labyrinthVM ?? makeVM(for: lab)

                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        LabyrinthGameView(viewModel: vm, onComplete: {
                            gameViewModel.completeCurrentLabyrinth()

                            // Check if this was the hard (final) difficulty of a story
                            let storyComplete = lab.difficulty == "hard"
                            isStoryComplete = storyComplete

                            showCompletion = true
                            Analytics.send("Game.completed", with: [
                                "labyrinthId": lab.id,
                                "difficulty": lab.difficulty,
                                "itemsCollected": String(vm.collectedItemIndices.count),
                                "totalItems": String(vm.totalItemCount)
                            ])

                            if storyComplete {
                                Analytics.send("StoryComplete.shown", with: [
                                    "labyrinthId": lab.id,
                                    "storyNumber": String(lab.storyNumber)
                                ])
                            }
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
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                    }
                }
                .ignoresSafeArea(.container, edges: .bottom)
                .persistentSystemOverlays(.hidden)

                if showCompletion {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { }

                    CompletionView(
                        labyrinth: lab,
                        onNext: {
                            if isStoryComplete {
                                // Story complete: dismiss game and navigate back to bookshelf
                                showCompletion = false
                                ttsService.stop()
                                Analytics.send("StoryComplete.backToBookshelf", with: [
                                    "labyrinthId": lab.id,
                                    "storyNumber": String(lab.storyNumber)
                                ])
                                gameViewModel.closeGame()
                                // Notify ContentView to reset to bookshelf
                                NotificationCenter.default.post(name: .returnToBookshelf, object: nil)
                            } else {
                                // Normal flow: advance to next labyrinth
                                showCompletion = false
                                ttsService.stop()
                                Analytics.send("Completion.nextTapped", with: ["labyrinthId": lab.id])
                                attemptNext()
                            }
                        },
                        onRepeat: {
                            showCompletion = false
                            isStoryComplete = false
                            vm.reset()
                            Analytics.send("Completion.repeatTapped", with: ["labyrinthId": lab.id])
                        },
                        collectedCount: vm.collectedItemIndices.count,
                        totalItemCount: vm.totalItemCount,
                        isStoryComplete: isStoryComplete
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
        .fullScreenCover(isPresented: $showParentalGate) {
            ParentalGateView(
                purpose: .paywall,
                onSuccess: {
                    showParentalGate = false
                    showPaywall = true
                },
                onCancel: {
                    showParentalGate = false
                }
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func attemptNext() {
        let nextIndex = gameViewModel.currentIndex + 1
        guard nextIndex < gameViewModel.labyrinths.count else { return }

        // Check if the next labyrinth is locked (index >= 3 for free users)
        if nextIndex >= 3 && !gameViewModel.isPremium {
            showParentalGate = true
            return
        }

        gameViewModel.nextLabyrinth()
        updateVM()
    }

    private func makeVM(for lab: Labyrinth) -> LabyrinthViewModel {
        let vm = LabyrinthViewModel(labyrinth: lab)
        DispatchQueue.main.async { self.labyrinthVM = vm }
        return vm
    }

    private func updateVM() {
        showCompletion = false
        isStoryComplete = false
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
                "difficulty": lab.difficulty
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
