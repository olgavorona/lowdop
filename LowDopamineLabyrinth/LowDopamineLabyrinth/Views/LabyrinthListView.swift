import SwiftUI

struct LabyrinthListView: View {
    @EnvironmentObject var gameViewModel: GameViewModel
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService
    @State private var showCompletion = false
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
                            gameViewModel.nextLabyrinth()
                            updateVM()
                        },
                        onReset: {
                            vm.reset()
                        },
                        onBack: {
                            ttsService.stop()
                            gameViewModel.closeGame()
                        }
                    )
                    .background(vm.backgroundColor.opacity(0.8))
                }

                if showCompletion {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { }

                    CompletionView(
                        labyrinth: lab,
                        onNext: {
                            showCompletion = false
                            ttsService.stop()
                            gameViewModel.nextLabyrinth()
                            updateVM()
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
        }
    }
}
