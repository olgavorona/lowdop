import SwiftUI

struct LabyrinthGameView: View {
    @ObservedObject var viewModel: LabyrinthViewModel
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var ttsService: TTSService
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let onComplete: () -> Void

    /// iPhone landscape = compact, iPad = regular
    private var isCompact: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            // Background
            viewModel.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar — title + instruction + optional item HUD
                HStack(spacing: 6) {
                    Text(viewModel.labyrinth.title)
                        .font(.system(size: isCompact ? 11 : 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .layoutPriority(1)

                    Text(viewModel.labyrinth.ttsInstruction)
                        .font(.system(size: isCompact ? 10 : 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(isCompact ? 1 : 2)

                    if viewModel.hasItems {
                        Spacer()
                        Text(viewModel.itemHUDText)
                            .font(.system(size: isCompact ? 12 : 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, isCompact ? 8 : 12)
                .padding(.vertical, isCompact ? 1 : 8)
                .background(Color.black.opacity(0.25))

                // Full-width maze
                GeometryReader { mazeGeo in
                    ZStack {
                        // Cartoonish ocean background pattern
                        OceanPatternView()
                            .opacity(0.15)

                        // Maze path
                        if viewModel.labyrinth.pathData.mazeType == "organic" {
                            viewModel.mazePath
                                .stroke(Color.white, style: StrokeStyle(
                                    lineWidth: CGFloat(viewModel.labyrinth.pathData.width) * viewModel.scale,
                                    lineCap: .round, lineJoin: .round))
                        } else if viewModel.labyrinth.pathData.mazeType.hasPrefix("corridor") {
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

                        // Item emoji overlay (between maze and drawing canvas)
                        if let items = viewModel.labyrinth.pathData.items {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                let isHidden = viewModel.isCollectType
                                    ? viewModel.collectedItemIndices.contains(index)
                                    : viewModel.hitItemIndices.contains(index)
                                if !isHidden {
                                    ZStack {
                                        if viewModel.isAvoidType {
                                            Circle()
                                                .fill(Color.red.opacity(0.25))
                                                .frame(width: viewModel.itemFontSize * 1.8,
                                                       height: viewModel.itemFontSize * 1.8)
                                                .position(viewModel.itemPoint(item))
                                                .allowsHitTesting(false)
                                        }
                                        Text(item.emoji)
                                            .font(.system(size: viewModel.itemFontSize))
                                            .position(viewModel.itemPoint(item))
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                        }

                        // Start marker — circled
                        startMarker

                        // End marker — full character shape, no circle clip
                        endMarker

                        // Drawing canvas overlay
                        DrawingCanvas(viewModel: viewModel, tolerance: preferences.pathTolerance)

                        // "Collect all items" hint
                        if viewModel.showItemHint {
                            Text(collectHintText)
                                .font(.system(size: isCompact ? 14 : 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(12)
                                .transition(.opacity)
                        }
                    }
                    .onAppear {
                        viewModel.canvasSize = mazeGeo.size
                        viewModel.setupValidator(tolerance: preferences.pathTolerance)
                    }
                    .onChange(of: mazeGeo.size) { newSize in
                        viewModel.canvasSize = newSize
                        viewModel.setupValidator(tolerance: preferences.pathTolerance)
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

    private var collectHintText: String {
        let emoji = viewModel.labyrinth.itemEmoji ?? ""
        let remaining = viewModel.totalItemCount - viewModel.collectedItemIndices.count
        return "Find all \(remaining) \(emoji) first!"
    }

    private var startMarker: some View {
        CharacterMarkerView(
            character: viewModel.labyrinth.characterStart,
            scale: viewModel.scale,
            isStart: true,
            clipToCircle: true
        )
        .position(viewModel.startPoint)
    }

    private var endMarker: some View {
        CharacterMarkerView(
            character: viewModel.labyrinth.characterEnd,
            scale: viewModel.scale,
            isStart: false,
            clipToCircle: false
        )
        .allowsHitTesting(false)
        .position(viewModel.endPoint)
    }
}

// MARK: - Ocean Background Pattern

struct OceanPatternView: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let waveCount = 6
                let bubblePositions: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.1, 0.2, 8), (0.3, 0.7, 12), (0.5, 0.3, 6),
                    (0.7, 0.8, 10), (0.85, 0.15, 7), (0.15, 0.5, 9),
                    (0.6, 0.55, 5), (0.9, 0.45, 11), (0.4, 0.9, 8),
                    (0.25, 0.35, 6), (0.75, 0.6, 7), (0.55, 0.1, 9),
                ]

                // Draw wavy lines
                for i in 0..<waveCount {
                    let y = size.height * CGFloat(i + 1) / CGFloat(waveCount + 1)
                    var path = SwiftUI.Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    let segments = 8
                    for s in 0..<segments {
                        let x1 = size.width * CGFloat(s) / CGFloat(segments) + size.width / CGFloat(segments) / 2
                        let x2 = size.width * CGFloat(s + 1) / CGFloat(segments)
                        let amp: CGFloat = (i % 2 == 0) ? 12 : -12
                        path.addQuadCurve(
                            to: CGPoint(x: x2, y: y),
                            control: CGPoint(x: x1, y: y + amp)
                        )
                    }
                    context.stroke(path, with: .color(.white), lineWidth: 1.5)
                }

                // Draw bubbles
                for (xFrac, yFrac, radius) in bubblePositions {
                    let center = CGPoint(x: size.width * xFrac, y: size.height * yFrac)
                    let rect = CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    context.stroke(
                        SwiftUI.Path(ellipseIn: rect),
                        with: .color(.white),
                        lineWidth: 1.2
                    )
                    // Highlight
                    let highlight = CGRect(
                        x: center.x - radius * 0.3, y: center.y - radius * 0.5,
                        width: radius * 0.4, height: radius * 0.3
                    )
                    context.fill(
                        SwiftUI.Path(ellipseIn: highlight),
                        with: .color(.white.opacity(0.4))
                    )
                }

                // Small starfish shapes
                let starPositions: [(CGFloat, CGFloat)] = [
                    (0.08, 0.85), (0.92, 0.9), (0.45, 0.05),
                ]
                for (xFrac, yFrac) in starPositions {
                    let center = CGPoint(x: size.width * xFrac, y: size.height * yFrac)
                    var star = SwiftUI.Path()
                    let points = 5
                    let outerR: CGFloat = 10
                    let innerR: CGFloat = 4
                    for j in 0..<(points * 2) {
                        let angle = CGFloat(j) * .pi / CGFloat(points) - .pi / 2
                        let r = j % 2 == 0 ? outerR : innerR
                        let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                        if j == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
                    }
                    star.closeSubpath()
                    context.stroke(star, with: .color(.white), lineWidth: 1.0)
                }
            }
        }
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
