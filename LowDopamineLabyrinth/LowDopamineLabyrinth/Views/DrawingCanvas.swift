import SwiftUI

struct DrawingCanvas: View {
    @ObservedObject var viewModel: LabyrinthViewModel
    let tolerance: CGFloat

    var body: some View {
        ZStack {
            // User's drawing trail
            Path { path in
                guard !viewModel.drawingPoints.isEmpty else { return }
                path.move(to: viewModel.drawingPoints[0])
                for point in viewModel.drawingPoints.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(
                viewModel.isOnPath ? Color(hex: "#5BA8D9") ?? .blue : .red,
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
                )
        }
    }
}
