import SwiftUI

struct LetterGridView: View {
    let collection: TracingCollection
    let onBackToBookshelf: () -> Void

    @State private var selectedLetterIndex: Int?
    @State private var recordedCollectionOpen = false

    init(collection: TracingCollection = .letters, onBackToBookshelf: @escaping () -> Void) {
        self.collection = collection
        self.onBackToBookshelf = onBackToBookshelf
    }

    private var letters: [Character] { collection.characters }
    private let tabletColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 6)

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private var columns: [GridItem] {
        if isPhone {
            return [GridItem(.adaptive(minimum: 64, maximum: 90), spacing: 12)]
        }
        return tabletColumns
    }

    var body: some View {
        ZStack {
            AppColor.background
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button(action: onBackToBookshelf) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: isPhone ? 22 : 30, weight: .heavy))
                            .foregroundColor(AppColor.textPrimary)
                            .frame(width: isPhone ? 48 : 72, height: isPhone ? 48 : 72)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Back")

                    Text(AppLocalization.text(collection.title))
                        .font(.system(size: isPhone ? 28 : 34, weight: .heavy, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, isPhone ? 16 : 28)
                .padding(.top, isPhone ? 8 : 18)

                if isPhone || collection == .hiragana {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 20) {
                            letterGrid
                            if collection == .hiragana {
                                Text(verbatim: "KanjiVG © 2009–2011 Ulrich Apel · CC BY-SA 3.0\nhttps://kanjivg.tagaini.net/\nhttps://creativecommons.org/licenses/by-sa/3.0/")
                                    .font(.footnote)
                                    .foregroundColor(AppColor.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, isPhone ? 16 : 28)
                        .padding(.bottom, 24)
                    }
                } else {
                    letterGrid
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            guard !recordedCollectionOpen else { return }
            recordedCollectionOpen = true
            TracingAnalytics.collectionOpened(collection, appLocale: Analytics.currentLocale)
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedLetterIndex != nil },
            set: { if !$0 { selectedLetterIndex = nil } }
        )) {
            if let index = selectedLetterIndex {
                LetterTracingSessionView(
                    collection: collection,
                    initialIndex: index,
                    onClose: { selectedLetterIndex = nil }
                )
            }
        }
    }

    private var letterGrid: some View {
        LazyVGrid(columns: columns, spacing: isPhone ? 12 : 16) {
            ForEach(letters.indices, id: \.self) { index in
                Button {
                    selectedLetterIndex = index
                } label: {
                    Text(String(letters[index]))
                        .font(.system(size: isPhone ? 34 : 44, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: isPhone ? 68 : 88)
                        .background(Color(red: 0.08, green: 0.48, blue: 0.36))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel(collection == .letters
                    ? Text("Letter \(String(letters[index]))")
                    : Text(verbatim: String(letters[index])))
                .accessibilityIdentifier("tracing.glyph.\(String(letters[index]))")
            }
        }
    }
}

struct LetterTracingSessionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: LetterTracingViewModel
    let onClose: () -> Void

    init(collection: TracingCollection = .letters, initialIndex: Int, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: LetterTracingViewModel(collection: collection, initialIndex: initialIndex))
        self.onClose = onClose
    }

    var body: some View {
        LetterTracingScreen(viewModel: viewModel, onClose: {
            viewModel.endSession(reason: "close")
            onClose()
        })
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tracing.screen")
            .onAppear { viewModel.startSession(isActive: scenePhase == .active) }
            .onDisappear { viewModel.endSession(reason: "dismissed") }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: viewModel.resumeAnalytics()
                case .inactive: viewModel.pauseAnalytics(isBackground: false)
                case .background: viewModel.pauseAnalytics(isBackground: true)
                @unknown default: viewModel.pauseAnalytics(isBackground: false)
                }
            }
    }
}

final class LetterTracingViewModel: ObservableObject {
    let collection: TracingCollection
    let letters: [Character]
    private let tracingAnalytics: TracingAnalytics

    @Published private(set) var currentIndex: Int
    @Published var drawingStrokes: [[CGPoint]] = []
    @Published var currentStroke: [CGPoint] = []

    init(
        collection: TracingCollection = .letters,
        initialIndex: Int = 0,
        appLocale: String = Analytics.currentLocale,
        eventSender: @escaping TracingAnalytics.EventSender = { Analytics.send($0, with: $1, floatValue: $2) },
        analyticsClock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.collection = collection
        letters = collection.characters
        currentIndex = max(0, min(initialIndex, letters.count - 1))
        tracingAnalytics = TracingAnalytics(
            collection: collection, initialIndex: initialIndex, appLocale: appLocale,
            send: eventSender, now: analyticsClock
        )
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
        tracingAnalytics.navigate(to: currentIndex - 1, direction: "previous")
        currentIndex -= 1
        clearDrawing()
    }

    func next() {
        guard canGoNext else { return }
        tracingAnalytics.navigate(to: currentIndex + 1, direction: "next")
        currentIndex += 1
        clearDrawing()
    }

    func restart() {
        tracingAnalytics.reset(clearedStrokeCount: drawingStrokes.count + (currentStroke.isEmpty ? 0 : 1))
        clearDrawing()
    }

    private func clearDrawing() {
        drawingStrokes = []
        currentStroke = []
    }

    func handleDragPoint(_ point: CGPoint) {
        tracingAnalytics.drawingPoint()
        if currentStroke.isEmpty {
            currentStroke = [point]
        } else {
            currentStroke.append(point)
        }
    }

    func handleDragEnd() {
        tracingAnalytics.strokeEnded()
        guard !currentStroke.isEmpty else { return }
        drawingStrokes.append(currentStroke)
        currentStroke = []
    }

    func startSession(isActive: Bool = true) { tracingAnalytics.start(isActive: isActive) }
    func endSession(reason: String) { tracingAnalytics.end(reason: reason) }
    func pauseAnalytics(isBackground: Bool) { tracingAnalytics.pause(isBackground: isBackground) }
    func resumeAnalytics() { tracingAnalytics.resume() }
}

private struct LetterTracingScreen: View {
    @ObservedObject var viewModel: LetterTracingViewModel
    let onClose: () -> Void

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.96, blue: 0.89)
                .ignoresSafeArea()

            GeometryReader { geometry in
                let safeTop = geometry.safeAreaInsets.top
                let safeBottom = geometry.safeAreaInsets.bottom
                let controlSize: CGFloat = isPhone ? 54 : 88
                let sideInset: CGFloat = isPhone ? 8 : 14
                let topInset = safeTop + (isPhone ? 4 : 8)
                let bottomInset = safeBottom + (isPhone ? 4 : 8)
                let contentHorizontalInset = sideInset + controlSize + (isPhone ? 8 : 12)
                let contentVerticalInset: CGFloat = isPhone ? 6 : 10

                ZStack {
                    VStack(spacing: isPhone ? 8 : 14) {
                        strokeField(isExample: true)
                        strokeField(isExample: false)
                    }
                    .padding(.vertical, contentVerticalInset)
                    .padding(.horizontal, contentHorizontalInset)

                    FreeLetterDrawingCanvas(viewModel: viewModel)
                        .padding(.vertical, contentVerticalInset)
                        .padding(.horizontal, contentHorizontalInset)

                    cornerButton(
                        systemImage: "xmark",
                        action: onClose,
                        color: Color(red: 0.35, green: 0.39, blue: 0.48),
                        size: controlSize
                    )
                    .position(x: sideInset + controlSize / 2, y: topInset + controlSize / 2)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("tracing.close")

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
                    .accessibilityIdentifier("tracing.restart")

                    sideButton(
                        systemImage: "chevron.left",
                        action: viewModel.previous,
                        isDisabled: !viewModel.canGoPrevious,
                        size: controlSize,
                        color: Color(red: 0.08, green: 0.43, blue: 0.55)
                    )
                    .position(x: sideInset + controlSize / 2, y: geometry.size.height / 2)
                    .accessibilityLabel("Previous")
                    .accessibilityIdentifier("tracing.previous")

                    sideButton(
                        systemImage: "chevron.right",
                        action: viewModel.next,
                        isDisabled: !viewModel.canGoNext,
                        size: controlSize,
                        color: Color(red: 0.08, green: 0.48, blue: 0.36)
                    )
                    .position(x: geometry.size.width - sideInset - controlSize / 2, y: geometry.size.height / 2)
                    .accessibilityLabel("Next")
                    .accessibilityIdentifier("tracing.next")
                }
            }
        }
        .persistentSystemOverlays(.hidden)
    }

    private func strokeField(isExample: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(isExample ? 0.76 : 0.86))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.77, green: 0.70, blue: 0.58), lineWidth: 3)
            }
            .overlay {
                GeometryReader { geometry in
                    let glyphs = tracingCharacters.map { viewModel.collection.strokes(for: $0) }
                    let standardLayout = TracingRowLayout(size: geometry.size, collection: viewModel.collection, glyphs: glyphs)
                    let exampleLayout = TracingRowLayout(size: geometry.size, collection: viewModel.collection, glyphs: glyphs, minimumCopies: 2)
                    // Keep separate ordered and dotted copies when both remain readable.
                    let layout = isExample && exampleLayout.glyphHeight >= 140 ? exampleLayout : standardLayout
                    HStack(spacing: layout.copySpacing) {
                        ForEach(0..<layout.copies, id: \.self) { copy in
                            HStack(spacing: layout.glyphSpacing) {
                                ForEach(glyphs.indices, id: \.self) { index in
                                    StrokeTracingGlyph(
                                        strokes: glyphs[index],
                                        showsOrder: isExample && copy == 0,
                                        showsDots: isExample && (copy > 0 || layout.copies == 1)
                                    )
                                    .frame(width: layout.glyphWidths[index], height: layout.glyphHeight)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .allowsHitTesting(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tracingCharacters.joined(separator: " "))
            .accessibilityIdentifier(isExample ? "tracing.example" : "tracing.practice")
    }

    private var tracingCharacters: [String] {
        viewModel.collection == .letters
            ? [viewModel.currentLetter, viewModel.lowercaseLetter]
            : [viewModel.currentLetter]
    }

    private func cornerButton(
        systemImage: String,
        action: @escaping () -> Void,
        color: Color,
        size: CGFloat
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: isPhone ? 24 : 38, weight: .heavy))
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
                .font(.system(size: isPhone ? 28 : 44, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(isDisabled ? Color.gray.opacity(0.45) : color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(isDisabled)
    }
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
