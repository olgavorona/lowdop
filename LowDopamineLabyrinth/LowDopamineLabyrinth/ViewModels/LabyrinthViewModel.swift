import SwiftUI

class LabyrinthViewModel: ObservableObject {
    @Published var drawingStrokes: [[CGPoint]] = []
    @Published var currentStroke: [CGPoint] = []
    @Published var isCompleted: Bool = false
    @Published var showSolution: Bool = false
    @Published var hasStartedDrawing: Bool = false
    @Published var collectedItemIndices: Set<Int> = []
    @Published var showItemHint: Bool = false

    let labyrinth: Labyrinth
    private var validator: DrawingValidator?
    @Published var canvasSize: CGSize = .zero

    /// Cached tight bounding box — computed once on init.
    private let cachedContentBounds: CGRect

    var scale: CGFloat {
        guard canvasSize.width > 0 else { return 1.0 }
        let bounds = cachedContentBounds
        let scaleX = canvasSize.width / bounds.width
        let scaleY = canvasSize.height / bounds.height
        return min(scaleX, scaleY)
    }

    var offset: CGPoint {
        guard canvasSize.width > 0 else { return .zero }
        let bounds = cachedContentBounds
        let centerX = bounds.midX
        let centerY = bounds.midY
        return CGPoint(x: canvasSize.width / 2 - centerX * scale,
                       y: canvasSize.height / 2 - centerY * scale)
    }

    var isCollectType: Bool {
        labyrinth.itemRule == "collect"
    }

    var hasItems: Bool {
        labyrinth.pathData.items != nil && !(labyrinth.pathData.items?.isEmpty ?? true)
    }

    var totalItemCount: Int {
        labyrinth.pathData.items?.count ?? 0
    }

    var allItemsCollected: Bool {
        guard isCollectType else { return true }
        return collectedItemIndices.count >= totalItemCount
    }

    var itemFontSize: CGFloat {
        24 * scale
    }

    func itemPoint(_ item: ItemData) -> CGPoint {
        CGPoint(x: CGFloat(item.x) * scale + offset.x,
                y: CGFloat(item.y) * scale + offset.y)
    }

    var itemHUDText: String {
        guard let emoji = labyrinth.itemEmoji else { return "" }
        return "\(emoji) \(collectedItemIndices.count)/\(totalItemCount)"
    }

    init(labyrinth: Labyrinth) {
        self.labyrinth = labyrinth
        self.cachedContentBounds = labyrinth.contentBounds
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
        guard let validator = validator else { return }

        if !hasStartedDrawing {
            hasStartedDrawing = true
            currentStroke = [point]
        } else {
            currentStroke.append(point)
        }

        // Check item proximity
        checkItemProximity(point)

        // Completion: reach near the end character (radius matches visible character size)
        if validator.isNearEnd(point, endPoint: labyrinth.pathData.endPoint, radius: 60 * scale) {
            isCompleted = true
            showSolution = true
        }
    }

    private func checkItemProximity(_ point: CGPoint) {
        guard let items = labyrinth.pathData.items else { return }
        // Use path tolerance (if validator is set up) so items on adjacent paths
        // aren't accidentally collected, especially on harder difficulties
        let baseTolerance = validator?.tolerance ?? 30
        let radius: CGFloat = baseTolerance * scale

        for (index, item) in items.enumerated() {
            let itemPos = itemPoint(item)
            let dx = point.x - itemPos.x
            let dy = point.y - itemPos.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist <= radius && !collectedItemIndices.contains(index) {
                collectedItemIndices.insert(index)
            }
        }
    }

    func handleDragEnd() {
        guard !currentStroke.isEmpty else { return }
        drawingStrokes.append(currentStroke)
        currentStroke = []
    }

    func reset() {
        drawingStrokes = []
        currentStroke = []
        isCompleted = false
        showSolution = false
        hasStartedDrawing = false
        collectedItemIndices = []
        showItemHint = false
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
