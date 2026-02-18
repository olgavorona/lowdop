# Low Dopamine Labyrinth

A calm, story-based finger-tracing labyrinth app for kids ages 3-6. Designed as a low-stimulation alternative to typical children's games, featuring gentle themes, educational content, and text-to-speech narration.

## Features

- **Location-based progression**: explore ocean-themed locations (Coral Garden, Kelp Forest, Sandy Shore, etc.), each with its own set of labyrinths
- **30 labyrinths per location level**: each location contains 30 hand-crafted mazes that unlock sequentially as the child completes them
- **Age-appropriate content**: organic curved paths for ages 3-4, grid and shaped mazes for ages 5-6
- **Story-driven gameplay**: each labyrinth has a unique story, characters, educational question, and fun fact
- **Text-to-Speech**: automatic narration of instructions and completion messages
- **Gentle feedback**: light haptic vibration when off-path, soft celebrations on completion
- **Landscape-first design**: optimized for landscape orientation on both iPhone and iPad
- **Freemium model**: 1 free labyrinth per day, unlock all with subscription
- **Privacy-first**: no data collection, COPPA compliant, privacy policy accessible during onboarding
- **No external dependencies**: pure SwiftUI + AVFoundation + StoreKit 2

## Locations

The app is organized by underwater locations. Each location represents an area in Denny the crab's ocean world:

| Location | Description |
|----------|-------------|
| Sandy Shore | Gentle beach area for beginners |
| Coral Garden | Colorful coral reef exploration |
| Bubble Lagoon | Playful lagoon with bubbles |
| Starfish Cove | Cozy cove with sea stars |
| Kelp Forest | Towering underwater forest |
| Shipwreck Playground | Sunken ship adventure |
| Treasure Caves | Mysterious underwater caves |
| Current Highway | Fast-flowing ocean currents |
| Moonlit Reef | Nighttime reef adventure |
| Whale Song Valley | Deep ocean valley |

Each location contains 30 labyrinths across difficulty levels (easy, medium, hard). Labyrinths unlock one at a time as the child completes each one.

## Characters

10 ocean characters with unique illustrations:
- **Denny** (crab) — main character, guide
- **Finn** (tropical fish), **Stella** (starfish), **Ollie** (octopus)
- **Shelly** (turtle), **Bubbles** (pufferfish), **Pearl** (oyster)
- **Sandy** (hermit crab), **Mama Coral**, **Papa Reef**

## Project Structure

```
lowdop/
├── content-generator/          # Python content generation pipeline
│   ├── generator.py            # Main generator using Anthropic Claude API
│   ├── maze_generator.py       # SVG maze generation algorithms
│   ├── generate_characters.py  # Character image generation (DALL-E 3)
│   ├── config.yaml             # Themes, age groups, visual settings
│   ├── validate_content.py     # QA validation script
│   ├── templates/              # Claude API prompt templates
│   └── output/labyrinths/      # Generated labyrinth JSON files
│
└── LowDopamineLabyrinth/       # iOS SwiftUI app
    └── LowDopamineLabyrinth/
        ├── Models/             # Labyrinth, UserPreferences
        ├── Views/              # SwiftUI views (landscape-first)
        ├── ViewModels/         # LabyrinthViewModel, GameViewModel
        ├── Services/           # Loader, TTS, DrawingValidator, Subscriptions
        ├── Utilities/          # SVGPathParser
        └── Resources/Labyrinths/  # JSON labyrinth bundles per location
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

# Generate the full starter pack
python generator.py --starter-pack

# Generate custom labyrinths
python generator.py --age 4 --difficulty easy --theme animals --count 5
```

### Generate character images

```bash
export OPENAI_API_KEY="your-key-here"

# Generate all characters (transparent background PNGs)
python generate_characters.py

# Generate single character
python generate_characters.py --character denny

# Generate and install to Xcode assets
python generate_characters.py --install

# Post-process for transparency (DALL-E 3 may not produce true alpha):
# pip install rembg
# rembg i input.png output.png
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
- `id`, `age_range`, `difficulty`, `theme`, `title`, `location`
- `story_setup`, `instruction`, `tts_instruction`
- `character_start`, `character_end` (type, description, position, name, image_asset)
- `educational_question`, `fun_fact`, `completion_message`
- `path_data` (svg_path, solution_path, segments, start/end points, canvas dimensions, maze_type)
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
  -destination 'platform=iOS Simulator,name=iPad Air' \
  build

# Run tests
xcodebuild -project LowDopamineLabyrinth/LowDopamineLabyrinth.xcodeproj \
  -scheme LowDopamineLabyrinth \
  -destination 'platform=iOS Simulator,name=iPad Air' \
  -only-testing:LowDopamineLabyrinthTests \
  test
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
- **Landscape-only orientation** locked for both iPhone and iPad
- **SVG path parsing** converts maze path data to SwiftUI `Path` objects with coordinate scaling
- **Touch validation** uses point-to-line-segment distance with age-appropriate tolerance (20pt / 15pt)
- **Sequential unlock** — labyrinths unlock one at a time as the child completes each one
- **Content pipeline** generates stories via Claude API, merges with algorithmic maze SVG data
- **Character images** generated via DALL-E 3 with transparent backgrounds, post-processed with rembg
