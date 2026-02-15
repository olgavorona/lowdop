import SwiftUI

struct LabyrinthGameView: View {
    @ObservedObject var viewModel: LabyrinthViewModel
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background
            viewModel.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Story header
                VStack(spacing: 4) {
                    Text(viewModel.labyrinth.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(viewModel.labyrinth.storySetup)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)

                // Maze area with GeometryReader
                GeometryReader { geometry in
                    ZStack {
                        // Maze path
                        if viewModel.labyrinth.pathData.mazeType == "organic" {
                            viewModel.mazePath
                                .stroke(Color.white, style: StrokeStyle(
                                    lineWidth: CGFloat(viewModel.labyrinth.pathData.width) * viewModel.scale,
                                    lineCap: .round, lineJoin: .round))
                        } else {
                            viewModel.mazePath
                                .stroke(Color.white, style: StrokeStyle(
                                    lineWidth: 3 * viewModel.scale,
                                    lineCap: .round))
                        }

                        // Solution path (shown after completion)
                        if viewModel.showSolution && !viewModel.labyrinth.pathData.solutionPath.isEmpty {
                            viewModel.solutionPath
                                .stroke(Color.white.opacity(0.3), style: StrokeStyle(
                                    lineWidth: CGFloat(viewModel.labyrinth.pathData.width) * viewModel.scale,
                                    lineCap: .round, lineJoin: .round))
                        }

                        // Start marker — arrow
                        startMarker

                        // End marker — star
                        endMarker

                        // Drawing canvas overlay
                        DrawingCanvas(viewModel: viewModel, tolerance: preferences.pathTolerance)
                    }
                    .onAppear {
                        viewModel.canvasSize = geometry.size
                        viewModel.setupValidator(tolerance: preferences.pathTolerance)
                    }
                    .onChange(of: geometry.size) { newSize in
                        viewModel.canvasSize = newSize
                        viewModel.setupValidator(tolerance: preferences.pathTolerance)
                    }
                }
                .background(viewModel.backgroundColor.opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal, 8)

                // TTS toggle
                HStack {
                    Spacer()
                    Button(action: {
                        preferences.ttsEnabled.toggle()
                    }) {
                        Image(systemName: preferences.ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
        .onAppear {
            if preferences.ttsEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !ttsService.playAudio(viewModel.labyrinth.audioInstruction) {
                        ttsService.speak(viewModel.labyrinth.ttsInstruction, rate: preferences.ttsRate)
                    }
                }
            }
        }
        .onChange(of: viewModel.isCompleted) { completed in
            if completed {
                onComplete()
            }
        }
    }

    private var startMarker: some View {
        CharacterMarkerView(
            character: viewModel.labyrinth.characterStart,
            scale: viewModel.scale,
            isStart: true
        )
        .position(viewModel.startPoint)
    }

    private var endMarker: some View {
        CharacterMarkerView(
            character: viewModel.labyrinth.characterEnd,
            scale: viewModel.scale,
            isStart: false
        )
        .position(viewModel.endPoint)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct StarShape: Shape {
    let points: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio
        var path = Path()

        for i in 0..<(points * 2) {
            let angle = (CGFloat(i) * .pi / CGFloat(points)) - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(x: center.x + radius * cos(angle),
                                y: center.y + radius * sin(angle))
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
