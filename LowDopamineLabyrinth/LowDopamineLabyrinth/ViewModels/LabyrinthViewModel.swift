import SwiftUI

class LabyrinthViewModel: ObservableObject {
    @Published var drawingPoints: [CGPoint] = []
    @Published var isOnPath: Bool = true
    @Published var isCompleted: Bool = false
    @Published var showSolution: Bool = false
    @Published var hasStartedDrawing: Bool = false

    let labyrinth: Labyrinth
    private var validator: DrawingValidator?
    @Published var canvasSize: CGSize = .zero

    var scale: CGFloat {
        guard canvasSize.width > 0 else { return 1.0 }
        let scaleX = canvasSize.width / CGFloat(labyrinth.pathData.canvasWidth)
        let scaleY = canvasSize.height / CGFloat(labyrinth.pathData.canvasHeight)
        return min(scaleX, scaleY)
    }

    var offset: CGPoint {
        guard canvasSize.width > 0 else { return .zero }
        let scaledW = CGFloat(labyrinth.pathData.canvasWidth) * scale
        let scaledH = CGFloat(labyrinth.pathData.canvasHeight) * scale
        return CGPoint(x: (canvasSize.width - scaledW) / 2,
                       y: (canvasSize.height - scaledH) / 2)
    }

    init(labyrinth: Labyrinth) {
        self.labyrinth = labyrinth
    }

    func setupValidator(tolerance: CGFloat) {
        validator = DrawingValidator(
            segments: labyrinth.pathData.segments,
            tolerance: tolerance,
            scale: scale,
            offset: offset
        )
    }

    func handleDragPoint(_ point: CGPoint) {
        guard !isCompleted else { return }
        hasStartedDrawing = true
        drawingPoints.append(point)

        if let validator = validator {
            let onPath = validator.isPointOnPath(point)
            if !onPath && isOnPath {
                isOnPath = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.isOnPath = true
                }
            }

            if validator.isNearEnd(point, endPoint: labyrinth.pathData.endPoint) {
                isCompleted = true
                showSolution = true
            }
        }
    }

    func reset() {
        drawingPoints = []
        isOnPath = true
        isCompleted = false
        showSolution = false
        hasStartedDrawing = false
    }

    var mazePath: Path {
        SVGPathParser.parse(labyrinth.pathData.svgPath, scale: scale, offset: offset)
    }

    var solutionPath: Path {
        SVGPathParser.parse(labyrinth.pathData.solutionPath, scale: scale, offset: offset)
    }

    var startPoint: CGPoint {
        CGPoint(x: CGFloat(labyrinth.pathData.startPoint.x) * scale + offset.x,
                y: CGFloat(labyrinth.pathData.startPoint.y) * scale + offset.y)
    }

    var endPoint: CGPoint {
        CGPoint(x: CGFloat(labyrinth.pathData.endPoint.x) * scale + offset.x,
                y: CGFloat(labyrinth.pathData.endPoint.y) * scale + offset.y)
    }

    var backgroundColor: Color {
        Color(hex: labyrinth.visualTheme.backgroundColor) ?? Color.blue.opacity(0.7)
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
