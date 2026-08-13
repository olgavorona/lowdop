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
    @State private var shouldShowDiscountAfterRegularDismissal = false
    @State private var labyrinthVM: LabyrinthViewModel?
    @State private var didInjectUITestCompletion = false

    private var shouldReturnToBookshelfAfterCompletion: Bool {
        isStoryComplete || gameViewModel.isLastLabyrinthInPack
    }

    var body: some View {
        ZStack {
            if let lab = gameViewModel.currentLabyrinth {
                let vm = labyrinthVM ?? makeVM(for: lab)

                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        LabyrinthGameView(viewModel: vm, onComplete: {
                            let wasNewCompletion = gameViewModel.completeCurrentLabyrinth()

                            // Check if all 3 difficulty levels of this story are now completed
                            isStoryComplete = gameViewModel.isStoryComplete

                            showCompletion = true
                            Analytics.send("Game.completed", with: [
                                "labyrinthId": lab.id,
                                "difficulty": lab.difficulty,
                                "itemsCollected": String(vm.collectedItemIndices.count),
                                "totalItems": String(vm.totalItemCount)
                            ])

                            trackFreeMazeCompletionIfNeeded(
                                labyrinth: lab,
                                wasNewCompletion: wasNewCompletion
                            )

                            if isStoryComplete {
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
                            if shouldReturnToBookshelfAfterCompletion {
                                showCompletion = false
                                ttsService.stop()
                                Analytics.send("Completion.backToBookshelf", with: [
                                    "labyrinthId": lab.id,
                                    "storyNumber": String(lab.storyNumber),
                                    "reason": isStoryComplete ? "story_complete" : "pack_complete"
                                ])
                                gameViewModel.closeGame()
                                NotificationCenter.default.post(name: .returnToBookshelf, object: nil)
                            } else {
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
                        hitOwlCount: vm.hitOwlIndices.count,
                        totalAvoidCount: vm.labyrinth.pathData.avoidItems?.count ?? 0,
                        isStoryComplete: isStoryComplete,
                        showsBackToBookshelf: shouldReturnToBookshelfAfterCompletion
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            } else {
                VStack {
                    Text("No labyrinths available")
                        .font(.system(size: 18, design: .rounded))
                        .foregroundColor(AppColor.textTertiary)
                }
            }
        }
        .onAppear {
            updateVM()
            presentUITestCompletionIfNeeded()
        }
        .onChange(of: preferences.ttsEnabled) { enabled in
            if !enabled { ttsService.stop() }
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
        .sheet(isPresented: $showPaywall, onDismiss: handlePaywallSheetDismissed) {
            PaywallView(
                source: .levels,
                onDismissWithoutPurchase: handlePaywallDismissalWithoutPurchase
            )
        }
    }

    private func attemptNext() {
        let nextIndex = gameViewModel.currentIndex + 1
        guard nextIndex < gameViewModel.labyrinths.count else { return }

        if gameViewModel.isLabyrinthLocked(at: nextIndex) {
            Analytics.send("Paywall.entryTapped", with: ["source": PaywallSource.levels.rawValue])
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
            if let index = gameViewModel.labyrinths.firstIndex(where: { $0.id == lab.id }),
               gameViewModel.isFreeLabyrinth(at: index) {
                Analytics.send("free_maze_started", with: [
                    "maze_id": lab.id,
                    "free_maze_number": String(index + 1)
                ])
            }
            ttsService.prepareAudio(for: lab)
            if preferences.ttsEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    ttsService.playAudio(lab.audioInstruction)
                }
            }
        }
    }

    private func presentUITestCompletionIfNeeded() {
        guard !didInjectUITestCompletion,
              ProcessInfo.processInfo.arguments.contains("-uiTestShowCompletionForLastLevel") else {
            return
        }

        didInjectUITestCompletion = true
        _ = gameViewModel.completeCurrentLabyrinth()
        labyrinthVM?.isCompleted = true
        labyrinthVM?.showSolution = true
        showCompletion = true
    }

    private func trackFreeMazeCompletionIfNeeded(labyrinth: Labyrinth, wasNewCompletion: Bool) {
        guard wasNewCompletion,
              let completedIndex = gameViewModel.labyrinths.firstIndex(where: { $0.id == labyrinth.id }),
              gameViewModel.isFreeLabyrinth(at: completedIndex) else {
            return
        }

        let freeMazeNumber = subscriptionManager.recordFreeMazeCompletedIfNeeded(mazeId: labyrinth.id)

        Analytics.send("free_maze_completed", with: [
            "maze_id": labyrinth.id,
            "free_maze_number": String(freeMazeNumber ?? subscriptionManager.numberOfFreeMazesCompleted)
        ])

        if freeMazeNumber == 3 {
            Analytics.send("free_experience_completed")
            shouldShowDiscountAfterRegularDismissal = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                guard !subscriptionManager.isPremium,
                      !subscriptionManager.isDiscountEligible else { return }
                showPaywall = true
            }
        }
    }

    private func handlePaywallDismissalWithoutPurchase() {
        showDiscountAfterRegularDismissalIfNeeded()
    }

    private func handlePaywallSheetDismissed() {
        showDiscountAfterRegularDismissalIfNeeded()
    }

    private func showDiscountAfterRegularDismissalIfNeeded() {
        guard shouldShowDiscountAfterRegularDismissal,
              !subscriptionManager.isPremium else { return }

        shouldShowDiscountAfterRegularDismissal = false
        subscriptionManager.enableDiscountEligibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showPaywall = true
        }
    }

}
