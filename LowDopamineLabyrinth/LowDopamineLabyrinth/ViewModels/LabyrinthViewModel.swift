import SwiftUI

class LabyrinthViewModel: ObservableObject {
    @Published var drawingStrokes: [[CGPoint]] = []
    @Published var currentStroke: [CGPoint] = []
    @Published var isCompleted: Bool = false
    @Published var showSolution: Bool = false
    @Published var hasStartedDrawing: Bool = false
    @Published var collectedItemIndices: Set<Int> = []
    @Published var hitItemIndices: Set<Int> = []
    @Published var avoidedItemHits: Int = 0
    @Published var showItemHint: Bool = false

    let labyrinth: Labyrinth
    private var validator: DrawingValidator?
    @Published var canvasSize: CGSize = .zero

    /// Cached tight bounding box — computed once on init.
    private let cachedContentBounds: CGRect

    /// Tight bounding box for corridor mazes; full canvas for grid mazes.
    private static func computeContentBounds(for labyrinth: Labyrinth) -> CGRect {
        let isCorridor = labyrinth.pathData.mazeType.hasPrefix("corridor")
        guard isCorridor else {
            return CGRect(x: 0, y: 0,
                          width: CGFloat(labyrinth.pathData.canvasWidth),
                          height: CGFloat(labyrinth.pathData.canvasHeight))
        }

        var xs: [CGFloat] = []
        var ys: [CGFloat] = []
        for seg in labyrinth.pathData.segments {
            xs.append(CGFloat(seg.start.x))
            xs.append(CGFloat(seg.end.x))
            ys.append(CGFloat(seg.start.y))
            ys.append(CGFloat(seg.end.y))
        }
        xs.append(CGFloat(labyrinth.pathData.startPoint.x))
        xs.append(CGFloat(labyrinth.pathData.endPoint.x))
        ys.append(CGFloat(labyrinth.pathData.startPoint.y))
        ys.append(CGFloat(labyrinth.pathData.endPoint.y))
        if let items = labyrinth.pathData.items {
            for item in items {
                xs.append(CGFloat(item.x))
                ys.append(CGFloat(item.y))
            }
        }

        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return CGRect(x: 0, y: 0,
                          width: CGFloat(labyrinth.pathData.canvasWidth),
                          height: CGFloat(labyrinth.pathData.canvasHeight))
        }

        let margin: CGFloat = 60
        return CGRect(x: minX - margin, y: minY - margin,
                      width: (maxX - minX) + margin * 2,
                      height: (maxY - minY) + margin * 2)
    }

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

    var isAvoidType: Bool {
        labyrinth.itemRule == "avoid"
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
        if isCollectType {
            return "\(emoji) \(collectedItemIndices.count)/\(totalItemCount)"
        } else {
            return "\(emoji) Avoid!"
        }
    }

    init(labyrinth: Labyrinth) {
        self.labyrinth = labyrinth
        self.cachedContentBounds = Self.computeContentBounds(for: labyrinth)
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
            if isCollectType && !allItemsCollected {
                // Show hint — don't complete yet
                showItemHint = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.showItemHint = false
                }
            } else {
                isCompleted = true
                showSolution = true
            }
        }
    }

    private func checkItemProximity(_ point: CGPoint) {
        guard let items = labyrinth.pathData.items else { return }
        let radius: CGFloat = 30 * scale

        for (index, item) in items.enumerated() {
            let itemPos = itemPoint(item)
            let dx = point.x - itemPos.x
            let dy = point.y - itemPos.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist <= radius {
                if isCollectType && !collectedItemIndices.contains(index) {
                    collectedItemIndices.insert(index)
                } else if isAvoidType && !hitItemIndices.contains(index) {
                    avoidedItemHits += 1
                    hitItemIndices.insert(index)
                }
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
        hitItemIndices = []
        avoidedItemHits = 0
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
