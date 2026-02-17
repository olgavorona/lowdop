import SwiftUI

class LabyrinthViewModel: ObservableObject {
    @Published var drawingStrokes: [[CGPoint]] = []
    @Published var currentStroke: [CGPoint] = []
    @Published var isOnPath: Bool = true
    @Published var isCompleted: Bool = false
    @Published var showSolution: Bool = false
    @Published var hasStartedDrawing: Bool = false

    let labyrinth: Labyrinth
    private var validator: DrawingValidator?
    @Published var canvasSize: CGSize = .zero

    private var startedNearStart: Bool = false
    private var visitedSegments: Set<Int> = []
    private var passedGate: Bool = false
    private lazy var rawGatePoint: CGPoint? = parseRawGatePoint()

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
        guard let validator = validator else { return }

        let onPath = validator.isPointOnPath(point)

        // Always draw the point (kids should see their line), but track on/off path
        if !hasStartedDrawing {
            hasStartedDrawing = true
            // Check if they started near the start marker
            if validator.isNearStart(point, startPoint: labyrinth.pathData.startPoint, radius: 30 * scale) {
                startedNearStart = true
            }
            currentStroke = [point]
            isOnPath = onPath
            return
        }

        currentStroke.append(point)

        // Visual feedback: flash off-path indicator
        if !onPath && isOnPath {
            isOnPath = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isOnPath = true
            }
        } else if onPath {
            isOnPath = true
        }

        // Track visited segments (only on-path points count)
        if onPath, let segIdx = validator.nearestSegmentIndex(to: point) {
            visitedSegments.insert(segIdx)
        }

        // Check gate — penultimate solution waypoint ensures correct approach direction
        if onPath, let raw = rawGatePoint {
            let gate = CGPoint(x: raw.x * scale + offset.x, y: raw.y * scale + offset.y)
            let dx = point.x - gate.x
            let dy = point.y - gate.y
            if sqrt(dx * dx + dy * dy) <= 30 * scale {
                passedGate = true
            }
        }

        // Check completion — require ALL of:
        // 1. Started near start point
        // 2. Visited at least 50% of path segments
        // 3. Passed through the gate (penultimate solution waypoint)
        // 4. Currently near end point
        if onPath {
            let totalSegments = labyrinth.pathData.segments.count
            let requiredSegments = max(1, Int(Double(totalSegments) * 0.5))
            if startedNearStart
                && visitedSegments.count >= requiredSegments
                && passedGate
                && validator.isNearEnd(point, endPoint: labyrinth.pathData.endPoint, radius: 20 * scale) {
                isCompleted = true
                showSolution = true
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
        isOnPath = true
        isCompleted = false
        showSolution = false
        hasStartedDrawing = false
        startedNearStart = false
        visitedSegments = []
        passedGate = false
    }

    /// Parse the penultimate waypoint from the solution path (e.g. "M 76 82 L 188 82 L ...").
    /// Returns raw (unscaled) coordinates — scale at usage time.
    private func parseRawGatePoint() -> CGPoint? {
        let path = labyrinth.pathData.solutionPath
        guard !path.isEmpty else { return nil }
        // Normalize commas to spaces, then split
        let normalized = path.replacingOccurrences(of: ",", with: " ")
        let tokens = normalized.split(separator: " ").map(String.init)
        var waypoints: [(Double, Double)] = []
        var i = 0
        while i < tokens.count {
            let cmd = tokens[i]
            if (cmd == "M" || cmd == "L"), i + 2 < tokens.count,
               let x = Double(tokens[i + 1]),
               let y = Double(tokens[i + 2]) {
                waypoints.append((x, y))
                i += 3
            } else {
                i += 1
            }
        }
        guard waypoints.count >= 2 else { return nil }
        let gate = waypoints[waypoints.count - 2]
        return CGPoint(x: CGFloat(gate.0), y: CGFloat(gate.1))
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
