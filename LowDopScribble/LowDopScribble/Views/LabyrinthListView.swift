import SwiftUI

struct LabyrinthListView: View {
    @EnvironmentObject var gameViewModel: GameViewModel
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService
    @State private var showCompletion = false
    @State private var isStoryComplete = false
    @State private var labyrinthVM: LabyrinthViewModel?

    private let pathTolerance: CGFloat = 25

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
                            gameViewModel.completeCurrentLabyrinth()
                            isStoryComplete = gameViewModel.isStoryComplete
                            showCompletion = true
                            Analytics.send("Game.completed", with: [
                                "labyrinthId": lab.id,
                                "difficulty": lab.difficulty,
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
                                gameViewModel.nextLabyrinth()
                                updateVM()
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
                                gameViewModel.nextLabyrinth()
                                updateVM()
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
                    Text("No exercises available")
                        .font(.system(size: 18, design: .rounded))
                        .foregroundColor(AppColor.textTertiary)
                }
            }
        }
        .onAppear { updateVM() }
        .onChange(of: preferences.ttsEnabled) { enabled in
            if !enabled { ttsService.stop() }
        }
        .animation(.easeInOut(duration: 0.3), value: showCompletion)
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
                newVM.setupValidator(tolerance: pathTolerance)
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
