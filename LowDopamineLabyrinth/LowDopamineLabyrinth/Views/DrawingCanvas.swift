import SwiftUI

struct DrawingCanvas: View {
    @ObservedObject var viewModel: LabyrinthViewModel
    let tolerance: CGFloat

    private let onPathColor = Color(hex: "#5BA8D9") ?? .blue
    private let offPathColor = Color.red.opacity(0.6)

    var body: some View {
        ZStack {
            // Completed strokes
            ForEach(viewModel.drawingStrokes.indices, id: \.self) { strokeIndex in
                Path { path in
                    let stroke = viewModel.drawingStrokes[strokeIndex]
                    guard !stroke.isEmpty else { return }
                    path.move(to: stroke[0])
                    for point in stroke.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(onPathColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }

            // Current active stroke
            Path { path in
                guard !viewModel.currentStroke.isEmpty else { return }
                path.move(to: viewModel.currentStroke[0])
                for point in viewModel.currentStroke.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(
                viewModel.isOnPath ? onPathColor : offPathColor,
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )

            // Invisible touch capture layer
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            viewModel.handleDragPoint(value.location)
                            if !viewModel.isOnPath {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            viewModel.handleDragEnd()
                        }
                )
        }
    }
}
