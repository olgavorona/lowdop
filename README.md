# Low Dopamine Labyrinth

A calm, story-based finger-tracing labyrinth app for kids ages 3-6. Designed as a low-stimulation alternative to typical children's games, featuring gentle themes, educational content, and text-to-speech narration.

## Features

- **30 hand-crafted labyrinths** across three difficulty levels
- **Age-appropriate content**: organic curved paths for ages 3-4, grid and shaped mazes for ages 5-6
- **Story-driven gameplay**: each labyrinth has a unique story, characters, educational question, and fun fact
- **Text-to-Speech**: automatic narration of instructions and completion messages
- **Gentle feedback**: light haptic vibration when off-path, soft celebrations on completion
- **Freemium model**: 1 free labyrinth per day, unlock all with subscription
- **No external dependencies**: pure SwiftUI + AVFoundation + StoreKit 2

## Project Structure

```
lowdop/
├── content-generator/          # Python content generation pipeline
│   ├── generator.py            # Main generator using Anthropic Claude API
│   ├── maze_generator.py       # SVG maze generation algorithms
│   ├── config.yaml             # Themes, age groups, visual settings
│   ├── validate_content.py     # QA validation script
│   ├── templates/              # Claude API prompt templates
│   └── output/labyrinths/      # Generated labyrinth JSON files
│
└── LowDopamineLabyrinth/       # iOS SwiftUI app
    └── LowDopamineLabyrinth/
        ├── Models/             # Labyrinth, UserPreferences
        ├── Views/              # SwiftUI views
        ├── ViewModels/         # LabyrinthViewModel, GameViewModel
        ├── Services/           # Loader, TTS, DrawingValidator, Subscriptions
        ├── Utilities/          # SVGPathParser
        └── Resources/Labyrinths/  # 30 JSON labyrinth bundles
```

## Content Generation

### Prerequisites

```bash
cd content-generator
pip install -r requirements.txt
```

### Generate new labyrinths

```bash
# Set your Anthropic API key
export ANTHROPIC_API_KEY="your-key-here"

# Generate the full starter pack (30 labyrinths)
python generator.py --starter-pack

# Generate custom labyrinths
python generator.py --age 4 --difficulty easy --theme animals --count 5
```

### Validate content

```bash
python validate_content.py
```

### Maze types

| Type | Ages | Description |
|------|------|-------------|
| Organic | 3-4 | Curved spline paths with wide corridors (35px) |
| Grid | 4-5 | Rectangular maze with recursive backtracking (30px paths) |
| Shaped | 5-6 | Grid maze masked to shapes (triangle, tree, mountain, diamond, circle) |

## How to Add New Labyrinths

1. Generate JSON files using `content-generator/generator.py`
2. Copy new `.json` files to `LowDopamineLabyrinth/Resources/Labyrinths/`
3. Update `manifest.json` with new entries
4. Add file references to `project.pbxproj` (PBXFileReference + PBXBuildFile + PBXResourcesBuildPhase)
5. Build and test

### JSON Schema

Each labyrinth JSON contains:
- `id`, `age_range`, `difficulty`, `theme`, `title`
- `story_setup`, `instruction`, `tts_instruction`
- `character_start`, `character_end` (type, description, position)
- `educational_question`, `fun_fact`, `completion_message`
- `path_data` (svg_path, solution_path, segments, start/end points, canvas dimensions)
- `visual_theme` (background_color, decorative_elements)

## Build and Run

### Requirements
- Xcode 15+
- iOS 15.0+ deployment target
- macOS with iOS Simulator

### Build

```bash
# Build for simulator
xcodebuild -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj \
  -scheme LowDopamineLabyrinth \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Run in simulator
xcrun simctl install booted path/to/LowDopamineLabyrinth.app
xcrun simctl launch booted com.lowdopamine.labyrinth
```

Or open `LowDopamineLabyrinth.xcodeproj` in Xcode and press Run.

## Subscription Setup (App Store Connect)

Configure two subscription products in App Store Connect:

| Product ID | Type | Price |
|-----------|------|-------|
| `com.lowdopamine.labyrinth.monthly` | Auto-renewable monthly | $4.99 |
| `com.lowdopamine.labyrinth.yearly` | Auto-renewable yearly | $29.99 |

The app uses StoreKit 2 for all purchase operations. Free tier allows 1 labyrinth per day.

## Architecture

- **SwiftUI lifecycle** with `@StateObject` / `@EnvironmentObject` for state management
- **SVG path parsing** converts maze path data to SwiftUI `Path` objects with coordinate scaling
- **Touch validation** uses point-to-line-segment distance with age-appropriate tolerance (20pt / 15pt)
- **Content pipeline** generates stories via Claude API, merges with algorithmic maze SVG data
