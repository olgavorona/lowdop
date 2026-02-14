import Foundation

struct Labyrinth: Codable, Identifiable {
    let id: String
    let ageRange: String
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
    }
}

struct LabyrinthCharacter: Codable {
    let type: String
    let description: String
    let position: String
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

struct LabyrinthManifest: Codable {
    let total: Int
    let labyrinths: [ManifestEntry]
}

struct ManifestEntry: Codable {
    let id: String
    let ageRange: String
    let difficulty: String
    let theme: String
    let title: String

    enum CodingKeys: String, CodingKey {
        case id
        case ageRange = "age_range"
        case difficulty, theme, title
    }
}
