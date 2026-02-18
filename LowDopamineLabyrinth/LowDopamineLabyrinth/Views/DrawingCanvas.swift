import SwiftUI

struct DrawingCanvas: View {
    @ObservedObject var viewModel: LabyrinthViewModel
    let tolerance: CGFloat

    private let strokeColor = Color(hex: "#5BA8D9") ?? .blue

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
                .stroke(strokeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }

            // Current active stroke
            Path { path in
                guard !viewModel.currentStroke.isEmpty else { return }
                path.move(to: viewModel.currentStroke[0])
                for point in viewModel.currentStroke.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(strokeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

            // Invisible touch capture layer
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            viewModel.handleDragPoint(value.location)
                        }
                        .onEnded { _ in
                            viewModel.handleDragEnd()
                        }
                )
        }
    }
}
