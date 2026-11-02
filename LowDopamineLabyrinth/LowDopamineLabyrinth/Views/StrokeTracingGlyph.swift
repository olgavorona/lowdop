import SwiftUI

/// Ordered examples, dotted copies, and gray guides share the same stroke geometry.
struct StrokeTracingGlyph: View {
    let strokes: [TracingStroke]
    let showsOrder: Bool
    let showsDots: Bool

    private let colors = [
        Color(red: 0.08, green: 0.48, blue: 0.36),
        Color(red: 0.07, green: 0.43, blue: 0.62),
        Color(red: 0.75, green: 0.32, blue: 0.18),
        Color(red: 0.50, green: 0.26, blue: 0.66)
    ]

    var body: some View {
        Canvas { context, size in
            let bounds = TracingStroke.contentBounds(for: strokes)
            let writingSize = CGSize(width: size.height, height: size.height)
            let scale = size.height / 420
            let inkWidth = bounds.width / 109 * size.height
            context.translateBy(x: (size.width - inkWidth) / 2 - bounds.minX / 109 * size.height, y: 0)

            for stroke in strokes {
                context.stroke(
                    stroke.path(in: writingSize),
                    with: .color(Color(red: 0.21, green: 0.23, blue: 0.28).opacity(0.12)),
                    style: StrokeStyle(lineWidth: 28 * scale, lineCap: .round, lineJoin: .round)
                )
            }

            for (index, stroke) in strokes.enumerated() {
                if showsOrder {
                    let color = colors[index % colors.count]
                    context.stroke(
                        stroke.path(in: writingSize), with: .color(color.opacity(0.92)),
                        style: StrokeStyle(lineWidth: 8 * scale, lineCap: .round, lineJoin: .round)
                    )
                    if let cue = stroke.directionCue(in: writingSize) {
                        context.fill(arrow(at: cue.point, angle: cue.angle, size: 16 * scale), with: .color(color))
                    }
                }
                if showsDots {
                    let radius = max(2, 6 * scale)
                    for point in stroke.spacedPoints(in: writingSize, spacing: max(7, 22 * scale)) {
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                            with: .color(Color(red: 0.93, green: 0.32, blue: 0.24).opacity(0.78))
                        )
                    }
                }
            }

            // Draw numbers last so crossing paths cannot cover the stroke-order labels.
            if showsOrder {
                for (index, stroke) in strokes.enumerated() {
                    let point = stroke.numberPosition.cgPoint(in: writingSize)
                    let diameter = max(18, 36 * scale)
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter)),
                        with: .color(colors[index % colors.count])
                    )
                    context.draw(
                        Text(String(index + 1))
                            .font(.system(size: max(12, 22 * scale), weight: .heavy, design: .rounded))
                            .foregroundColor(.white),
                        at: point
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func arrow(at point: CGPoint, angle: CGFloat, size: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: point.x + cos(angle) * size, y: point.y + sin(angle) * size))
            for offset in [CGFloat.pi - 0.72, CGFloat.pi + 0.72] {
                path.addLine(to: CGPoint(x: point.x + cos(angle + offset) * size, y: point.y + sin(angle + offset) * size))
            }
            path.closeSubpath()
        }
    }
}
