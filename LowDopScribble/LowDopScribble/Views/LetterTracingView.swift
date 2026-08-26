import SwiftUI

struct LetterGridView: View {
    let onBackToBookshelf: () -> Void

    @State private var selectedLetterIndex: Int?

    private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 6)

    var body: some View {
        ZStack {
            AppColor.background
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button(action: onBackToBookshelf) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundColor(AppColor.textPrimary)
                            .frame(width: 72, height: 72)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Back")

                    Text("Letters")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(letters.indices, id: \.self) { index in
                        Button {
                            selectedLetterIndex = index
                        } label: {
                            Text(String(letters[index]))
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 88)
                                .background(Color(red: 0.08, green: 0.48, blue: 0.36))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityLabel("Letter \(String(letters[index]))")
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedLetterIndex != nil },
            set: { if !$0 { selectedLetterIndex = nil } }
        )) {
            if let index = selectedLetterIndex {
                LetterTracingSessionView(
                    initialIndex: index,
                    onClose: { selectedLetterIndex = nil }
                )
            }
        }
    }
}

struct LetterTracingSessionView: View {
    @StateObject private var viewModel: LetterTracingViewModel
    let onClose: () -> Void

    init(initialIndex: Int, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: LetterTracingViewModel(initialIndex: initialIndex))
        self.onClose = onClose
    }

    var body: some View {
        LetterTracingScreen(viewModel: viewModel, onClose: onClose)
            .accessibilityIdentifier("tracing.screen")
    }
}

final class LetterTracingViewModel: ObservableObject {
    let letters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    @Published private(set) var currentIndex: Int
    @Published var drawingStrokes: [[CGPoint]] = []
    @Published var currentStroke: [CGPoint] = []

    init(initialIndex: Int = 0) {
        currentIndex = max(0, min(initialIndex, letters.count - 1))
    }

    var currentLetter: String {
        String(letters[currentIndex])
    }

    var lowercaseLetter: String {
        currentLetter.lowercased()
    }

    var canGoPrevious: Bool {
        currentIndex > 0
    }

    var canGoNext: Bool {
        currentIndex < letters.count - 1
    }

    func previous() {
        guard canGoPrevious else { return }
        currentIndex -= 1
        restart()
    }

    func next() {
        guard canGoNext else { return }
        currentIndex += 1
        restart()
    }

    func restart() {
        drawingStrokes = []
        currentStroke = []
    }

    func handleDragPoint(_ point: CGPoint) {
        if currentStroke.isEmpty {
            currentStroke = [point]
        } else {
            currentStroke.append(point)
        }
    }

    func handleDragEnd() {
        guard !currentStroke.isEmpty else { return }
        drawingStrokes.append(currentStroke)
        currentStroke = []
    }
}

private struct LetterTracingScreen: View {
    @ObservedObject var viewModel: LetterTracingViewModel
    let onClose: () -> Void

    private let tracingFontSize: CGFloat = 420
    private let cueFrameSize = CGSize(width: 420, height: 420)
    private let letterPairSpacing: CGFloat = -56

    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.96, blue: 0.89)
                .ignoresSafeArea()

            GeometryReader { geometry in
                let safeTop = geometry.safeAreaInsets.top
                let safeBottom = geometry.safeAreaInsets.bottom
                let controlSize: CGFloat = 88
                let sideInset: CGFloat = 14
                let topInset = safeTop + 8
                let bottomInset = safeBottom + 8
                let contentHorizontalInset = sideInset + controlSize + 12

                ZStack {
                    VStack(spacing: 14) {
                        topLetterField
                        bottomLetterField
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, contentHorizontalInset)

                    FreeLetterDrawingCanvas(viewModel: viewModel)
                        .padding(.vertical, 10)
                        .padding(.horizontal, contentHorizontalInset)

                    cornerButton(
                        systemImage: "xmark",
                        action: onClose,
                        color: Color(red: 0.35, green: 0.39, blue: 0.48),
                        size: controlSize
                    )
                    .position(x: sideInset + controlSize / 2, y: topInset + controlSize / 2)
                    .accessibilityLabel("Close")

                    cornerButton(
                        systemImage: "arrow.counterclockwise",
                        action: viewModel.restart,
                        color: Color(red: 0.75, green: 0.32, blue: 0.18),
                        size: controlSize
                    )
                    .position(
                        x: sideInset + controlSize / 2,
                        y: geometry.size.height - bottomInset - controlSize / 2
                    )
                    .accessibilityLabel("Restart")

                    sideButton(
                        systemImage: "chevron.left",
                        action: viewModel.previous,
                        isDisabled: !viewModel.canGoPrevious,
                        size: controlSize,
                        color: Color(red: 0.08, green: 0.43, blue: 0.55)
                    )
                    .position(x: sideInset + controlSize / 2, y: geometry.size.height / 2)
                    .accessibilityLabel("Previous")

                    sideButton(
                        systemImage: "chevron.right",
                        action: viewModel.next,
                        isDisabled: !viewModel.canGoNext,
                        size: controlSize,
                        color: Color(red: 0.08, green: 0.48, blue: 0.36)
                    )
                    .position(x: geometry.size.width - sideInset - controlSize / 2, y: geometry.size.height / 2)
                    .accessibilityLabel("Next")
                }
            }
        }
        .persistentSystemOverlays(.hidden)
    }

    private var topLetterField: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.76))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.77, green: 0.70, blue: 0.58), lineWidth: 3)
            }
            .overlay {
                GeometryReader { geometry in
                    let layout = letterLayout(for: geometry.size.width)

                    HStack(spacing: 28) {
                        ForEach(0..<exampleCount(for: geometry.size.width), id: \.self) { index in
                            HStack(spacing: layout.letterSpacing) {
                                Text(viewModel.currentLetter)
                                    .frame(width: layout.glyphFrameSize.width, height: layout.glyphFrameSize.height)
                                    .overlay {
                                        if index == 0 {
                                            FirstStrokeCue(letter: viewModel.currentLetter)
                                                .frame(width: layout.glyphFrameSize.width, height: layout.glyphFrameSize.height)
                                        }
                                    }

                                Text(viewModel.lowercaseLetter)
                                    .frame(width: layout.glyphFrameSize.width, height: layout.glyphFrameSize.height)
                            }
                            .font(.system(size: layout.fontSize, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.21, green: 0.23, blue: 0.28).opacity(0.17))
                            .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                }
                .allowsHitTesting(false)
            }
    }

    private var bottomLetterField: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.86))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.77, green: 0.70, blue: 0.58), lineWidth: 3)
            }
            .overlay {
                GeometryReader { geometry in
                    let layout = letterLayout(for: geometry.size.width)

                    HStack(spacing: 28) {
                        ForEach(0..<exampleCount(for: geometry.size.width), id: \.self) { _ in
                            DottedStrokeLetterPair(
                                capital: viewModel.currentLetter,
                                lowercase: viewModel.lowercaseLetter,
                                fontSize: layout.fontSize,
                                glyphFrameSize: layout.glyphFrameSize,
                                letterSpacing: layout.letterSpacing
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                }
                .allowsHitTesting(false)
            }
    }

    private func exampleCount(for width: CGFloat) -> Int {
        width >= 1_700 ? 2 : 1
    }

    private func letterLayout(for width: CGFloat) -> LetterPairLayout {
        let availableWidth = max(1, width - 32)
        let pairWidth = cueFrameSize.width * 2 + letterPairSpacing
        let scale = min(1, availableWidth / pairWidth)

        return LetterPairLayout(
            fontSize: tracingFontSize * scale,
            glyphFrameSize: CGSize(
                width: cueFrameSize.width * scale,
                height: cueFrameSize.height * scale
            ),
            letterSpacing: letterPairSpacing * scale
        )
    }

    private func cornerButton(
        systemImage: String,
        action: @escaping () -> Void,
        color: Color,
        size: CGFloat
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func sideButton(
        systemImage: String,
        action: @escaping () -> Void,
        isDisabled: Bool,
        size: CGFloat,
        color: Color
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(isDisabled ? Color.gray.opacity(0.45) : color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(isDisabled)
    }
}

private struct LetterPairLayout {
    let fontSize: CGFloat
    let glyphFrameSize: CGSize
    let letterSpacing: CGFloat
}

private struct DottedStrokeLetterPair: View {
    let capital: String
    let lowercase: String
    let fontSize: CGFloat
    let glyphFrameSize: CGSize
    let letterSpacing: CGFloat

    var body: some View {
        HStack(spacing: letterSpacing) {
            DottedStrokeLetter(letter: capital)
                .frame(width: glyphFrameSize.width, height: glyphFrameSize.height)

            Text(lowercase)
                .frame(width: glyphFrameSize.width, height: glyphFrameSize.height)
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundColor(Color(red: 0.16, green: 0.18, blue: 0.24).opacity(0.12))
        }
        .lineLimit(1)
    }
}

private struct DottedStrokeLetter: View {
    let letter: String

    private let dotSize: CGFloat = 12
    private let dotStep: CGFloat = 22

    var body: some View {
        GeometryReader { geometry in
            ForEach(LetterStrokeCue.cues(for: letter)) { cue in
                let points = dottedPoints(for: cue, in: geometry.size)

                ForEach(points.indices, id: \.self) { index in
                    Circle()
                        .fill(Color(red: 0.93, green: 0.32, blue: 0.24).opacity(0.78))
                        .frame(width: dotSize, height: dotSize)
                        .position(points[index])
                }
            }
        }
    }

    private func dottedPoints(for cue: LetterStrokeCue, in size: CGSize) -> [CGPoint] {
        let start = cue.start.cgPoint(in: size)
        let control1 = cue.control1.cgPoint(in: size)
        let control2 = cue.control2.cgPoint(in: size)
        let end = cue.end.cgPoint(in: size)
        let sampleCount = 40
        let samples = (0...sampleCount).map { index in
            cubicPoint(
                t: CGFloat(index) / CGFloat(sampleCount),
                start: start,
                control1: control1,
                control2: control2,
                end: end
            )
        }
        let approximateLength = zip(samples, samples.dropFirst()).reduce(CGFloat.zero) { length, pair in
            length + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
        let dotCount = max(2, Int(approximateLength / dotStep))

        return (0...dotCount).map { index in
            cubicPoint(
                t: CGFloat(index) / CGFloat(dotCount),
                start: start,
                control1: control1,
                control2: control2,
                end: end
            )
        }
    }

    private func cubicPoint(
        t: CGFloat,
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint
    ) -> CGPoint {
        let oneMinusT = 1 - t
        let x = pow(oneMinusT, 3) * start.x
            + 3 * pow(oneMinusT, 2) * t * control1.x
            + 3 * oneMinusT * pow(t, 2) * control2.x
            + pow(t, 3) * end.x
        let y = pow(oneMinusT, 3) * start.y
            + 3 * pow(oneMinusT, 2) * t * control1.y
            + 3 * oneMinusT * pow(t, 2) * control2.y
            + pow(t, 3) * end.y

        return CGPoint(x: x, y: y)
    }
}

private struct FirstStrokeCue: View {
    let letter: String

    private let arrowHeadSize: CGFloat = 18
    private let arrowHeadSpread: CGFloat = 0.72

    private var cues: [LetterStrokeCue] {
        LetterStrokeCue.cues(for: letter)
    }

    var body: some View {
        GeometryReader { geometry in
            ForEach(cues) { cue in
                let start = cue.start.cgPoint(in: geometry.size)
                let end = cue.end.cgPoint(in: geometry.size)
                let angle = Angle(radians: atan2(end.y - start.y, end.x - start.x))

                Path { path in
                    path.move(to: start)
                    path.addCurve(
                        to: end,
                        control1: cue.control1.cgPoint(in: geometry.size),
                        control2: cue.control2.cgPoint(in: geometry.size)
                    )
                }
                .stroke(cue.color.opacity(0.92), style: StrokeStyle(lineWidth: 8, lineCap: .round))

                Circle()
                    .fill(cue.color)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text("\(cue.order)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .position(start)

                arrowHead(at: end, angle: angle.radians)
                    .fill(cue.color.opacity(0.95))
            }
        }
    }

    private func arrowHead(at end: CGPoint, angle: CGFloat) -> Path {
        let tip = CGPoint(
            x: end.x + cos(angle) * arrowHeadSize,
            y: end.y + sin(angle) * arrowHeadSize
        )
        let back1 = CGPoint(
            x: end.x + cos(angle + .pi - arrowHeadSpread) * arrowHeadSize,
            y: end.y + sin(angle + .pi - arrowHeadSpread) * arrowHeadSize
        )
        let back2 = CGPoint(
            x: end.x + cos(angle + .pi + arrowHeadSpread) * arrowHeadSize,
            y: end.y + sin(angle + .pi + arrowHeadSpread) * arrowHeadSize
        )

        return Path { path in
            path.move(to: tip)
            path.addLine(to: back1)
            path.addLine(to: back2)
            path.closeSubpath()
        }
    }
}

private extension UnitPoint {
    func cgPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}

private struct LetterStrokeCue: Identifiable {
    let order: Int
    let start: UnitPoint
    let control1: UnitPoint
    let control2: UnitPoint
    let end: UnitPoint

    var id: Int { order }

    var color: Color {
        switch order {
        case 1:
            return Color(red: 0.08, green: 0.48, blue: 0.36)
        case 2:
            return Color(red: 0.07, green: 0.43, blue: 0.62)
        case 3:
            return Color(red: 0.75, green: 0.32, blue: 0.18)
        default:
            return Color(red: 0.50, green: 0.26, blue: 0.66)
        }
    }

    static func cues(for letter: String) -> [LetterStrokeCue] {
        cues[letter] ?? [
            stroke(1, 0.30, 0.18, 0.30, 0.36, 0.30, 0.58, 0.30, 0.76)
        ]
    }

    private static func stroke(
        _ order: Int,
        _ sx: CGFloat, _ sy: CGFloat,
        _ c1x: CGFloat, _ c1y: CGFloat,
        _ c2x: CGFloat, _ c2y: CGFloat,
        _ ex: CGFloat, _ ey: CGFloat
    ) -> LetterStrokeCue {
        LetterStrokeCue(
            order: order,
            start: UnitPoint(x: sx, y: sy),
            control1: UnitPoint(x: c1x, y: c1y),
            control2: UnitPoint(x: c2x, y: c2y),
            end: UnitPoint(x: ex, y: ey)
        )
    }

    // BEGIN GENERATED LETTER STROKE CUES
    private static let cues: [String: [LetterStrokeCue]] = [
        "A": [
            stroke(1, 0.498, 0.108, 0.337, 0.389, 0.206, 0.657, 0.155, 0.8),
            stroke(2, 0.506, 0.105, 0.66, 0.428, 0.798, 0.622, 0.852, 0.777),
            stroke(3, 0.237, 0.597, 0.43, 0.62, 0.586, 0.612, 0.771, 0.615)
        ],
        "B": [
            stroke(1, 0.272, 0.15, 0.278, 0.38, 0.278, 0.62, 0.278, 0.78),
            stroke(2, 0.332, 0.141, 0.888, 0.107, 0.743, 0.486, 0.299, 0.388),
            stroke(3, 0.353, 0.433, 0.946, 0.408, 1, 0.88, 0.319, 0.817)
        ],
        "C": [
            stroke(1, 0.801, 0.332, 0, 0, 0.035, 0.911, 0.653, 0.737)
        ],
        "D": [
            stroke(1, 0.269, 0.281, 0.28, 0.353, 0.28, 0.56, 0.28, 0.78),
            stroke(2, 0.339, 0.272, 0.987, 0.295, 0.796, 0.827, 0.3, 0.78)
        ],
        "E": [
            stroke(1, 0.258, 0.261, 0.26, 0.353, 0.26, 0.56, 0.26, 0.78),
            stroke(2, 0.272, 0.265, 0.458, 0.27, 0.587, 0.265, 0.705, 0.274),
            stroke(3, 0.28, 0.49, 0.427, 0.49, 0.553, 0.49, 0.66, 0.49),
            stroke(4, 0.28, 0.78, 0.44, 0.78, 0.6, 0.78, 0.76, 0.78)
        ],
        "F": [
            stroke(1, 0.251, 0.262, 0.26, 0.353, 0.26, 0.56, 0.26, 0.78),
            stroke(2, 0.267, 0.259, 0.496, 0.281, 0.6, 0.267, 0.709, 0.273),
            stroke(3, 0.28, 0.49, 0.427, 0.49, 0.553, 0.49, 0.66, 0.49)
        ],
        "G": [
            stroke(1, 0.7, 0.33, 0.074, 0.05, 0, 1, 0.773, 0.616),
            stroke(2, 0.574, 0.535, 0.639, 0.535, 0.714, 0.533, 0.822, 0.53)
        ],
        "H": [
            stroke(1, 0.252, 0.249, 0.25, 0.353, 0.25, 0.56, 0.25, 0.78),
            stroke(2, 0.75, 0.252, 0.75, 0.353, 0.75, 0.56, 0.75, 0.78),
            stroke(3, 0.28, 0.5, 0.427, 0.5, 0.573, 0.5, 0.72, 0.5)
        ],
        "I": [
            stroke(1, 0.497, 0.248, 0.5, 0.33, 0.5, 0.62, 0.5, 0.78)
        ],
        "J": [
            stroke(1, 0.612, 0.255, 0.6, 0.42, 0.687, 1, 0.338, 0.658)
        ],
        "K": [
            stroke(1, 0.27, 0.252, 0.27, 0.353, 0.27, 0.56, 0.27, 0.78),
            stroke(2, 0.669, 0.248, 0.587, 0.3, 0.447, 0.413, 0.3, 0.52),
            stroke(3, 0.34, 0.52, 0.473, 0.6, 0.613, 0.687, 0.768, 0.784)
        ],
        "L": [
            stroke(1, 0.268, 0.241, 0.27, 0.353, 0.27, 0.56, 0.27, 0.78),
            stroke(2, 0.29, 0.78, 0.443, 0.78, 0.597, 0.78, 0.75, 0.78)
        ],
        "M": [
            stroke(1, 0.18, 0.78, 0.18, 0.56, 0.18, 0.353, 0.18, 0.249),
            stroke(2, 0.252, 0.253, 0.287, 0.307, 0.393, 0.44, 0.439, 0.537),
            stroke(3, 0.498, 0.598, 0.607, 0.44, 0.713, 0.307, 0.738, 0.299),
            stroke(4, 0.821, 0.245, 0.82, 0.353, 0.82, 0.56, 0.82, 0.78)
        ],
        "N": [
            stroke(1, 0.22, 0.78, 0.22, 0.56, 0.22, 0.353, 0.224, 0.244),
            stroke(2, 0.276, 0.248, 0.42, 0.36, 0.607, 0.567, 0.78, 0.78),
            stroke(3, 0.78, 0.78, 0.78, 0.56, 0.78, 0.353, 0.777, 0.248)
        ],
        "O": [
            stroke(1, 0.501, 0.245, 0.21, 0.145, 0.111, 0.851, 0.56, 0.78),
            stroke(2, 0.56, 0.78, 0.859, 0.793, 0.858, 0.239, 0.569, 0.257)
        ],
        "P": [
            stroke(1, 0.28, 0.78, 0.28, 0.56, 0.28, 0.353, 0.279, 0.256),
            stroke(2, 0.381, 0.268, 0.871, 0.231, 0.863, 0.627, 0.431, 0.584)
        ],
        "Q": [
            stroke(1, 0.485, 0.255, 0.067, 0.285, 0.085, 0.817, 0.56, 0.78),
            stroke(2, 0.56, 0.78, 0.86, 0.78, 0.95, 0.362, 0.578, 0.243),
            stroke(3, 0.595, 0.615, 0.665, 0.69, 0.72, 0.76, 0.8, 0.835)
        ],
        "R": [
            stroke(1, 0.28, 0.78, 0.28, 0.56, 0.28, 0.353, 0.277, 0.269),
            stroke(2, 0.34, 0.267, 0.716, 0.21, 0.873, 0.517, 0.34, 0.52),
            stroke(3, 0.38, 0.52, 0.5, 0.6, 0.627, 0.687, 0.76, 0.78)
        ],
        "S": [
            stroke(1, 0.692, 0.3, 0.248, 0.115, 0.145, 0.539, 0.5, 0.485),
            stroke(2, 0.5, 0.485, 0.925, 0.549, 0.76, 0.835, 0.3, 0.76)
        ],
        "T": [
            stroke(1, 0.241, 0.267, 0.414, 0.259, 0.601, 0.272, 0.761, 0.273),
            stroke(2, 0.498, 0.281, 0.5, 0.36, 0.5, 0.56, 0.5, 0.78)
        ],
        "U": [
            stroke(1, 0.255, 0.297, 0.202, 1, 0.842, 0.933, 0.759, 0.281)
        ],
        "V": [
            stroke(1, 0.239, 0.248, 0.293, 0.4, 0.393, 0.607, 0.5, 0.78),
            stroke(2, 0.5, 0.78, 0.607, 0.607, 0.707, 0.4, 0.768, 0.248)
        ],
        "W": [
            stroke(1, 0.126, 0.248, 0.207, 0.4, 0.267, 0.607, 0.32, 0.78),
            stroke(2, 0.32, 0.78, 0.375, 0.603, 0.434, 0.556, 0.488, 0.322),
            stroke(3, 0.514, 0.273, 0.607, 0.575, 0.639, 0.61, 0.68, 0.78),
            stroke(4, 0.68, 0.78, 0.747, 0.607, 0.807, 0.4, 0.876, 0.244)
        ],
        "X": [
            stroke(1, 0.259, 0.242, 0.353, 0.337, 0.513, 0.54, 0.7, 0.78),
            stroke(2, 0.706, 0.235, 0.587, 0.337, 0.42, 0.54, 0.22, 0.78)
        ],
        "Y": [
            stroke(1, 0.25, 0.239, 0.293, 0.28, 0.393, 0.387, 0.5, 0.48),
            stroke(2, 0.733, 0.241, 0.707, 0.28, 0.607, 0.387, 0.5, 0.48),
            stroke(3, 0.5, 0.48, 0.5, 0.573, 0.5, 0.673, 0.5, 0.78)
        ],
        "Z": [
            stroke(1, 0.218, 0.262, 0.396, 0.245, 0.566, 0.263, 0.695, 0.269),
            stroke(2, 0.707, 0.268, 0.586, 0.377, 0.393, 0.54, 0.22, 0.78),
            stroke(3, 0.22, 0.78, 0.407, 0.78, 0.587, 0.78, 0.76, 0.78)
        ]
    ]
    // END GENERATED LETTER STROKE CUES
}

private struct FreeLetterDrawingCanvas: View {
    @ObservedObject var viewModel: LetterTracingViewModel

    private let outlineStyle = StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round)
    private let fillStyle = StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)

    var body: some View {
        ZStack {
            ForEach(viewModel.drawingStrokes.indices, id: \.self) { index in
                strokePath(viewModel.drawingStrokes[index])
                    .stroke(Color.black.opacity(0.24), style: outlineStyle)
                strokePath(viewModel.drawingStrokes[index])
                    .stroke(Color(red: 0.92, green: 0.22, blue: 0.18), style: fillStyle)
            }

            strokePath(viewModel.currentStroke)
                .stroke(Color.black.opacity(0.24), style: outlineStyle)
            strokePath(viewModel.currentStroke)
                .stroke(Color(red: 0.92, green: 0.22, blue: 0.18), style: fillStyle)

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

    private func strokePath(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }
}
