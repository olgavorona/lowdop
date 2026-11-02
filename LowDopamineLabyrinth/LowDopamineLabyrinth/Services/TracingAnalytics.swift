import Foundation

/// Measures tracing interest and foreground engagement without storing drawings.
final class TracingAnalytics {
    typealias EventSender = (String, [String: String], Double?) -> Void

    private struct Counters {
        var activeSeconds: TimeInterval = 0
        var drawingSeconds: TimeInterval = 0
        var strokes = 0
        var resets = 0
    }

    private let collection: TracingCollection
    private let appLocale: String
    private let send: EventSender
    private let now: () -> TimeInterval
    private var index: Int
    private var hasStarted = false
    private var hasEnded = false
    private var activeSince: TimeInterval?
    private var drawingSince: TimeInterval?
    private var totals = Counters()
    private var segment = Counters()
    private var viewedCharacters: Set<String> = []
    private var practicedCharacters: Set<String> = []
    private var characterVisits = 0
    private var hasDrawnOnVisit = false

    init(
        collection: TracingCollection,
        initialIndex: Int,
        appLocale: String,
        send: @escaping EventSender = { Analytics.send($0, with: $1, floatValue: $2) },
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.collection = collection
        self.index = max(0, min(initialIndex, collection.characters.count - 1))
        self.appLocale = appLocale
        self.send = send
        self.now = now
    }

    static func collectionOpened(
        _ collection: TracingCollection,
        appLocale: String,
        send: EventSender = { Analytics.send($0, with: $1, floatValue: $2) }
    ) {
        send("Tracing.collectionOpened", [
            "collection": collection.rawValue,
            "app_locale": appLocale,
            "character_count": String(collection.characters.count)
        ], nil)
    }

    func start(isActive: Bool) {
        guard !hasStarted, !hasEnded else { return }
        hasStarted = true
        if isActive { activeSince = now() }
        send("Tracing.sessionStarted", characterProperties, nil)
        recordCharacterView(entry: "grid")
    }

    func resume() {
        guard hasStarted, !hasEnded, activeSince == nil else { return }
        activeSince = now()
    }

    func pause(isBackground: Bool) {
        guard hasStarted, !hasEnded else { return }
        accumulateTime()
        activeSince = nil
        drawingSince = nil
        if isBackground { sendEngagement(reason: "background") }
    }

    /// Called for drag samples, but sends only once when drawing starts on a visit.
    func drawingPoint() {
        guard hasStarted, !hasEnded, activeSince != nil, drawingSince == nil else { return }
        accumulateTime()
        drawingSince = now()
        totals.strokes += 1
        segment.strokes += 1
        practicedCharacters.insert(character)
        if !hasDrawnOnVisit {
            hasDrawnOnVisit = true
            send("Tracing.drawingStarted", characterProperties, nil)
        }
    }

    func strokeEnded() {
        guard hasStarted, !hasEnded else { return }
        accumulateTime()
        drawingSince = nil
    }

    func reset(clearedStrokeCount: Int) {
        guard hasStarted, !hasEnded else { return }
        accumulateTime()
        drawingSince = nil
        totals.resets += 1
        segment.resets += 1
        send("Tracing.reset", characterProperties.merging([
            "cleared_stroke_count": String(clearedStrokeCount)
        ]) { _, new in new }, nil)
    }

    func navigate(to newIndex: Int, direction: String) {
        let target = max(0, min(newIndex, collection.characters.count - 1))
        guard target != index, !hasEnded else { return }
        if hasStarted {
            accumulateTime()
            drawingSince = nil
            sendEngagement(reason: direction, nextCharacter: String(collection.characters[target]))
        }
        index = target
        hasDrawnOnVisit = false
        if hasStarted { recordCharacterView(entry: direction) }
    }

    func end(reason: String) {
        guard hasStarted, !hasEnded else { return }
        accumulateTime()
        activeSince = nil
        drawingSince = nil
        sendEngagement(reason: reason)
        hasEnded = true
        var properties = collectionProperties.merging(counterProperties(totals)) { _, new in new }
        properties["reason"] = reason
        properties["characters_viewed"] = String(characterVisits)
        properties["unique_characters_viewed"] = String(viewedCharacters.count)
        properties["characters_practiced"] = String(practicedCharacters.count)
        send("Tracing.sessionEnded", properties, totals.activeSeconds)
    }

    private var character: String { String(collection.characters[index]) }

    private var collectionProperties: [String: String] {
        ["collection": collection.rawValue, "app_locale": appLocale]
    }

    private var characterProperties: [String: String] {
        var properties = collectionProperties
        properties["character"] = character
        properties["character_index"] = String(index)
        if collection == .letters { properties["lowercase_character"] = character.lowercased() }
        return properties
    }

    private func recordCharacterView(entry: String) {
        characterVisits += 1
        viewedCharacters.insert(character)
        send("Tracing.characterViewed", characterProperties.merging(["entry": entry]) { _, new in new }, nil)
    }

    private func accumulateTime() {
        let timestamp = now()
        if let start = activeSince {
            let elapsed = max(0, timestamp - start)
            totals.activeSeconds += elapsed
            segment.activeSeconds += elapsed
            activeSince = timestamp
        }
        if let start = drawingSince {
            let elapsed = max(0, timestamp - start)
            totals.drawingSeconds += elapsed
            segment.drawingSeconds += elapsed
            drawingSince = timestamp
        }
    }

    /// Each segment is sent once; background checkpoints preserve usage before force quit.
    private func sendEngagement(reason: String, nextCharacter: String? = nil) {
        guard segment.activeSeconds > 0 || segment.strokes > 0 || segment.resets > 0 else { return }
        var properties = characterProperties.merging(counterProperties(segment)) { _, new in new }
        properties["reason"] = reason
        if let nextCharacter { properties["next_character"] = nextCharacter }
        send("Tracing.engagement", properties, segment.activeSeconds)
        if segment.drawingSeconds > 0 {
            send("Tracing.drawingDuration", properties, segment.drawingSeconds)
        }
        segment = Counters()
    }

    private func counterProperties(_ counters: Counters) -> [String: String] {
        [
            "active_seconds": seconds(counters.activeSeconds),
            "drawing_seconds": seconds(counters.drawingSeconds),
            "stroke_count": String(counters.strokes),
            "reset_count": String(counters.resets)
        ]
    }

    private func seconds(_ value: TimeInterval) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
