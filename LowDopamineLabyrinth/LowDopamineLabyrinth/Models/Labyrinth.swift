import Foundation
import CoreGraphics

struct ItemData: Codable {
    let x: Double
    let y: Double
    let emoji: String
    let onSolution: Bool?

    enum CodingKeys: String, CodingKey {
        case x, y, emoji
        case onSolution = "on_solution"
    }
}

struct Labyrinth: Codable, Identifiable {
    let id: String
    let ageRange: String?
    let difficulty: String
    let theme: String
    let title: String
    let storySetup: String
    let instruction: String
    let ttsInstruction: String
    let characterStart: LabyrinthCharacter
    let characterEnd: LabyrinthCharacter
    let educationalQuestion: String
    let funFact: String
    let completionMessage: String
    let pathData: PathData
    let visualTheme: VisualTheme
    let location: String?
    let audioInstruction: String?
    let audioCompletion: String?
    let itemRule: String?
    let itemEmoji: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ageRange = "age_range"
        case difficulty, theme, title
        case storySetup = "story_setup"
        case instruction
        case ttsInstruction = "tts_instruction"
        case characterStart = "character_start"
        case characterEnd = "character_end"
        case educationalQuestion = "educational_question"
        case funFact = "fun_fact"
        case completionMessage = "completion_message"
        case pathData = "path_data"
        case visualTheme = "visual_theme"
        case location
        case audioInstruction = "audio_instruction"
        case audioCompletion = "audio_completion"
        case itemRule = "item_rule"
        case itemEmoji = "item_emoji"
    }
}

struct LabyrinthCharacter: Codable {
    let type: String
    let description: String
    let position: String
    let name: String?
    let imageAsset: String?

    enum CodingKeys: String, CodingKey {
        case type, description, position, name
        case imageAsset = "image_asset"
    }
}

struct PathData: Codable {
    let svgPath: String
    let solutionPath: String
    let width: Double
    let complexity: String
    let mazeType: String
    let startPoint: PointData
    let endPoint: PointData
    let segments: [SegmentData]
    let canvasWidth: Double
    let canvasHeight: Double
    let controlPoints: [PointData]?
    let items: [ItemData]?

    enum CodingKeys: String, CodingKey {
        case svgPath = "svg_path"
        case solutionPath = "solution_path"
        case width, complexity
        case mazeType = "maze_type"
        case startPoint = "start_point"
        case endPoint = "end_point"
        case segments
        case canvasWidth = "canvas_width"
        case canvasHeight = "canvas_height"
        case controlPoints = "control_points"
        case items
    }
}

struct PointData: Codable {
    let x: Double
    let y: Double
}

struct SegmentData: Codable {
    let start: PointData
    let end: PointData
}

struct VisualTheme: Codable {
    let backgroundColor: String
    let decorativeElements: [String]

    enum CodingKeys: String, CodingKey {
        case backgroundColor = "background_color"
        case decorativeElements = "decorative_elements"
    }
}

extension Labyrinth {
    /// Bounding box for scaling — uses full canvas for all maze types.
    /// Corridor SVG paths include the entire maze structure (not just the
    /// solution), so a tight box from solution segments would over-zoom.
    var contentBounds: CGRect {
        return CGRect(x: 0, y: 0,
                      width: CGFloat(pathData.canvasWidth),
                      height: CGFloat(pathData.canvasHeight))
    }
}

struct LabyrinthManifest: Codable {
    let total: Int
    let labyrinths: [ManifestEntry]
}

struct ManifestEntry: Codable {
    let id: String
    let difficulty: String
    let theme: String
    let title: String
    let location: String?

    enum CodingKeys: String, CodingKey {
        case id, difficulty, theme, title, location
    }
}
