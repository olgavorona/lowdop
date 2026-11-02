import SwiftUI

enum TracingCollection: String, CaseIterable {
    case letters = "letter_tracing"
    case numbers = "number_tracing"
    case hiragana = "hiragana_tracing"

    var characters: [Character] {
        switch self {
        case .letters: return Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        case .numbers: return Array("0123456789")
        case .hiragana: return Array("あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん")
        }
    }

    var title: String {
        switch self {
        case .letters: return "Letters"
        case .numbers: return "Numbers"
        case .hiragana: return "Hiragana"
        }
    }

    var countLabel: String {
        switch self {
        case .letters: return "26 letters"
        case .numbers: return "10 numbers"
        case .hiragana: return "46 hiragana"
        }
    }

    var freeLabel: String {
        switch self {
        case .letters: return "Free · 26 letters"
        case .numbers: return "Free · 10 numbers"
        case .hiragana: return "Free · 46 hiragana"
        }
    }

    func isAvailable(in language: AppLanguage) -> Bool {
        self != .hiragana || language == .japanese
    }

    func strokes(for character: String) -> [TracingStroke] {
        switch self {
        case .letters: return Self.latinStrokes[character] ?? []
        case .numbers: return Self.numberStrokes[character] ?? []
        case .hiragana: return Self.hiraganaStrokes[character] ?? []
        }
    }

    private struct StrokeResource: Decodable {
        let glyphs: [String: [TracingStroke]]
    }

    private static let latinStrokes = loadStrokes(named: "latin-strokes")
    private static let hiraganaStrokes = loadStrokes(named: "hiragana-strokes")

    private static func loadStrokes(named name: String) -> [String: [TracingStroke]] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let resource = try? JSONDecoder().decode(StrokeResource.self, from: data) else {
            assertionFailure("The bundled \(name) stroke paths could not be loaded")
            return [:]
        }
        return resource.glyphs
    }

    // Original, unjoined handwriting paths in the same 109 × 109 coordinate space.
    // Every array entry is one pen-down stroke; consecutive curves never lift the pen.
    private static let numberStrokes: [String: [TracingStroke]] = [
        "0": [TracingStroke(start: .init(55, 21), curves: [
            .init(24, 21, 24, 87, 55, 87), .init(86, 87, 86, 21, 55, 21)
        ], numberPosition: .init(47, 14))],
        "1": [
            TracingStroke(start: .init(42, 37), curves: [
                .line(from: .init(42, 37), to: .init(61, 21))
            ], numberPosition: .init(32, 35)),
            TracingStroke(start: .init(61, 21), curves: [
                .line(from: .init(61, 21), to: .init(61, 87))
            ], numberPosition: .init(71, 17))
        ],
        "2": [TracingStroke(start: .init(31, 36), curves: [
            .init(33, 14, 76, 14, 77, 35), .init(78, 49, 49, 70, 31, 87),
            .line(from: .init(31, 87), to: .init(79, 87))
        ], numberPosition: .init(23, 30))],
        "3": [TracingStroke(start: .init(32, 27), curves: [
            .init(56, 10, 95, 34, 53, 51), .init(91, 49, 88, 92, 53, 88),
            .init(44, 88, 37, 85, 31, 79)
        ], numberPosition: .init(23, 23))],
        "4": [
            TracingStroke(start: .init(64, 21), curves: [
                .line(from: .init(64, 21), to: .init(29, 65)),
                .line(from: .init(29, 65), to: .init(81, 65))
            ], numberPosition: .init(53, 17)),
            TracingStroke(start: .init(69, 21), curves: [
                .line(from: .init(69, 21), to: .init(69, 88))
            ], numberPosition: .init(81, 24))
        ],
        "5": [
            TracingStroke(start: .init(38, 22), curves: [
                .line(from: .init(38, 22), to: .init(34, 51)),
                .init(81, 37, 94, 87, 57, 88), .init(45, 88, 37, 85, 31, 79)
            ], numberPosition: .init(26, 22)),
            TracingStroke(start: .init(38, 22), curves: [
                .line(from: .init(38, 22), to: .init(78, 22))
            ], numberPosition: .init(47, 12))
        ],
        "6": [TracingStroke(start: .init(70, 21), curves: [
            .init(48, 30, 27, 56, 32, 75), .init(37, 99, 82, 91, 77, 66),
            .init(73, 48, 41, 50, 32, 69)
        ], numberPosition: .init(78, 15))],
        "7": [TracingStroke(start: .init(30, 22), curves: [
            .line(from: .init(30, 22), to: .init(79, 22)),
            .line(from: .init(79, 22), to: .init(46, 88))
        ], numberPosition: .init(22, 17))],
        "8": [TracingStroke(start: .init(55, 21), curves: [
            .init(24, 21, 27, 43, 55, 54), .init(87, 67, 85, 89, 55, 89),
            .init(25, 89, 23, 67, 55, 54), .init(83, 43, 86, 21, 55, 21)
        ], numberPosition: .init(50, 12))],
        "9": [TracingStroke(start: .init(76, 42), curves: [
            .init(77, 15, 31, 14, 31, 41), .init(31, 67, 75, 68, 76, 42),
            .init(76, 59, 65, 78, 45, 89)
        ], numberPosition: .init(87, 40))]
    ]
}

struct TracingPoint: Codable, Equatable {
    let x: Double
    let y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    func cgPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: x / 109 * size.width, y: y / 109 * size.height)
    }
}

struct TracingCurve: Codable {
    let control1: TracingPoint
    let control2: TracingPoint
    let end: TracingPoint

    init(_ c1x: Double, _ c1y: Double, _ c2x: Double, _ c2y: Double, _ ex: Double, _ ey: Double) {
        control1 = TracingPoint(c1x, c1y)
        control2 = TracingPoint(c2x, c2y)
        end = TracingPoint(ex, ey)
    }

    static func line(from start: TracingPoint, to end: TracingPoint) -> TracingCurve {
        TracingCurve(
            start.x + (end.x - start.x) / 3, start.y + (end.y - start.y) / 3,
            start.x + (end.x - start.x) * 2 / 3, start.y + (end.y - start.y) * 2 / 3,
            end.x, end.y
        )
    }

    func point(at t: CGFloat, from start: CGPoint, in size: CGSize) -> CGPoint {
        let c1 = control1.cgPoint(in: size)
        let c2 = control2.cgPoint(in: size)
        let end = end.cgPoint(in: size)
        let u = 1 - t
        return CGPoint(
            x: u * u * u * start.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * end.x,
            y: u * u * u * start.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * end.y
        )
    }
}

struct TracingStroke: Codable {
    let start: TracingPoint
    let curves: [TracingCurve]
    let numberPosition: TracingPoint

    var isDot: Bool {
        curves.allSatisfy { curve in
            [curve.control1, curve.control2, curve.end].allSatisfy {
                hypot($0.x - start.x, $0.y - start.y) <= 3
            }
        }
    }

    /// Crop horizontal whitespace only: every glyph keeps the same baseline and height.
    static func contentBounds(for strokes: [TracingStroke]) -> CGRect {
        guard !strokes.isEmpty else { return CGRect(x: 0, y: 0, width: 109, height: 109) }
        var bounds = CGRect.null
        for stroke in strokes {
            bounds = bounds.union(stroke.path(in: CGSize(width: 109, height: 109)).boundingRect)
            bounds = bounds.union(CGRect(
                x: stroke.numberPosition.x - 5, y: stroke.numberPosition.y - 5,
                width: 10, height: 10
            ))
        }
        return bounds.insetBy(dx: -6, dy: 0)
    }

    func path(in size: CGSize) -> Path {
        Path { path in
            path.move(to: start.cgPoint(in: size))
            for curve in curves {
                path.addCurve(
                    to: curve.end.cgPoint(in: size),
                    control1: curve.control1.cgPoint(in: size),
                    control2: curve.control2.cgPoint(in: size)
                )
            }
        }
    }

    /// Equal-distance samples keep the dots legible through tight loops and slow curves.
    func spacedPoints(in size: CGSize, spacing: CGFloat) -> [CGPoint] {
        guard spacing > 0 else { return [] }
        let samples = flattenedPoints(in: size)
        guard let first = samples.first else { return [] }
        var points = [first]
        var remaining = spacing
        for (start, end) in zip(samples, samples.dropFirst()) {
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length > 0 else { continue }
            var travelled: CGFloat = 0
            while remaining <= length - travelled {
                travelled += remaining
                let t = travelled / length
                points.append(CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t))
                remaining = spacing
            }
            remaining -= length - travelled
        }
        if let end = curves.last?.end,
           hypot(end.x - self.start.x, end.y - self.start.y) < 0.001,
           let last = points.last, points.count > 2,
           hypot(last.x - first.x, last.y - first.y) < spacing * 0.5 {
            points.removeLast()
        }
        return points
    }

    /// A direction arrow inside the stroke also works for closed loops (0, 8, の).
    func directionCue(in size: CGSize) -> (point: CGPoint, angle: CGFloat)? {
        guard !isDot else { return nil }
        let points = spacedPoints(in: size, spacing: max(1, size.width / 109))
        guard points.count > 2 else { return nil }
        let index = max(1, min(points.count - 2, Int(CGFloat(points.count) * 0.28)))
        let before = points[index - 1]
        let after = points[index + 1]
        return (points[index], atan2(after.y - before.y, after.x - before.x))
    }

    private func flattenedPoints(in size: CGSize) -> [CGPoint] {
        var current = start.cgPoint(in: size)
        var points = [current]
        for curve in curves {
            // KanjiVG includes short lead-ins and long loops in the same stroke.
            let c1 = curve.control1.cgPoint(in: size)
            let c2 = curve.control2.cgPoint(in: size)
            let end = curve.end.cgPoint(in: size)
            let polygonLength = hypot(c1.x - current.x, c1.y - current.y)
                + hypot(c2.x - c1.x, c2.y - c1.y) + hypot(end.x - c2.x, end.y - c2.y)
            let steps = max(8, Int(ceil(polygonLength / 2)))
            for step in 1...steps {
                points.append(curve.point(at: CGFloat(step) / CGFloat(steps), from: current, in: size))
            }
            current = end
        }
        return points
    }
}

/// Fit readable writing samples using their ink width rather than an empty square.
struct TracingRowLayout {
    let copies: Int
    let glyphHeight: CGFloat
    let glyphWidths: [CGFloat]
    let glyphSpacing: CGFloat = 16
    let copySpacing: CGFloat = 28

    init(size: CGSize, collection: TracingCollection, glyphs: [[TracingStroke]], minimumCopies: Int = 1) {
        let aspects = glyphs.map { TracingStroke.contentBounds(for: $0).width / 109 }
        let totalAspect = max(0.01, aspects.reduce(0, +))
        let availableWidth = max(1, size.width - 32)
        let availableHeight = max(1, size.height - 24)
        let innerSpacing = CGFloat(max(0, glyphs.count - 1)) * glyphSpacing
        let preferredHeight = min(collection == .numbers ? 250 : 320, availableHeight)
        let preferredWidth = preferredHeight * totalAspect + innerSpacing
        let maximumCopies = collection == .hiragana ? 2 : 12
        copies = max(1, min(maximumCopies, max(minimumCopies, Int((availableWidth + copySpacing) / (preferredWidth + copySpacing)))))
        let widthForInk = availableWidth - CGFloat(copies - 1) * copySpacing - CGFloat(copies) * innerSpacing
        let height = max(1, min(380, availableHeight, widthForInk / (CGFloat(copies) * totalAspect)))
        glyphHeight = height
        glyphWidths = aspects.map { $0 * height }
    }
}
