import SwiftUI

struct DrawingCanvas: View {
    @ObservedObject var viewModel: LabyrinthViewModel
    let tolerance: CGFloat

    private let outlineStyle = StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
    private let fillStyle = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)

    var body: some View {
        ZStack {
            // Completed strokes
            ForEach(viewModel.drawingStrokes.indices, id: \.self) { strokeIndex in
                let strokePath = Path { path in
                    let stroke = viewModel.drawingStrokes[strokeIndex]
                    guard !stroke.isEmpty else { return }
                    path.move(to: stroke[0])
                    for point in stroke.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                strokePath.stroke(Color.black.opacity(0.3), style: outlineStyle)
                strokePath.stroke(Color.white, style: fillStyle)
            }

            // Current active stroke
            let currentPath = Path { path in
                guard !viewModel.currentStroke.isEmpty else { return }
                path.move(to: viewModel.currentStroke[0])
                for point in viewModel.currentStroke.dropFirst() {
                    path.addLine(to: point)
                }
            }
            currentPath.stroke(Color.black.opacity(0.3), style: outlineStyle)
            currentPath.stroke(Color.white, style: fillStyle)

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
