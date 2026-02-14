"""
Labyrinth Content Generator using Anthropic API.

Generates story packages (JSON) paired with maze SVG data
for the Low Dopamine Labyrinth iOS app.
"""

import argparse
import json
import os
import random
import sys
from pathlib import Path

import yaml

try:
    import anthropic
except ImportError:
    print("Error: anthropic package not installed. Run: pip install anthropic")
    sys.exit(1)

from maze_generator import FullMazeGenerator


def load_config() -> dict:
    config_path = Path(__file__).parent / "config.yaml"
    with open(config_path) as f:
        return yaml.safe_load(f)


def load_prompt_template() -> str:
    template_path = Path(__file__).parent / "templates" / "story_prompt.txt"
    with open(template_path) as f:
        return f.read()


def get_age_group(age: int, config: dict) -> dict:
    if age <= 4:
        return config["age_groups"]["young"]
    elif age <= 5:
        return config["age_groups"]["middle"]
    else:
        return config["age_groups"]["older"]


def generate_story(client: anthropic.Anthropic, age: int, difficulty: str, theme: str) -> dict:
    """Call Claude API to generate a story package."""
    template = load_prompt_template()
    prompt = template.format(age=age, difficulty=difficulty, theme=theme)

    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )

    response_text = message.content[0].text.strip()
    # Strip markdown code fences if present
    if response_text.startswith("```"):
        lines = response_text.split("\n")
        lines = [l for l in lines if not l.startswith("```")]
        response_text = "\n".join(lines)

    return json.loads(response_text)


def generate_labyrinth(
    client: anthropic.Anthropic,
    lab_id: str,
    age: int,
    difficulty: str,
    theme: str,
    config: dict,
) -> dict:
    """Generate a complete labyrinth: story + maze data."""
    age_group = get_age_group(age, config)

    # Pick shape
    shapes = age_group["shapes"]
    shape = random.choice(shapes)

    # Generate maze
    maze_gen = FullMazeGenerator()
    maze_data = maze_gen.generate_maze(
        difficulty=difficulty,
        age=age,
        shape=shape,
        canvas_width=600,
        canvas_height=500,
    )

    # Generate story via Claude API
    story = generate_story(client, age, difficulty, theme)

    # Get visual theme
    visual_themes = config.get("visual_themes", {})
    vt = visual_themes.get(theme, {
        "background_color": "#4A90E2",
        "decorative_elements": ["stars"],
    })

    # Generate preview SVG
    svg = maze_gen.to_full_svg(maze_data, vt["background_color"])

    # Combine into full labyrinth package
    labyrinth = {
        "id": lab_id,
        "age_range": f"{age}-{age+1}" if age < 6 else "5-6",
        "difficulty": difficulty,
        "theme": theme,
        "title": story.get("title", f"The {theme.title()} Adventure"),
        "story_setup": story.get("story_setup", ""),
        "instruction": story.get("instruction", ""),
        "tts_instruction": story.get("tts_instruction", ""),
        "character_start": story.get("character_start", {
            "type": "child",
            "description": "A friendly child",
            "position": "bottom_left",
        }),
        "character_end": story.get("character_end", {
            "type": "goal",
            "description": "The destination",
            "position": "top_right",
        }),
        "educational_question": story.get("educational_question", ""),
        "fun_fact": story.get("fun_fact", ""),
        "completion_message": story.get("completion_message", "Well done!"),
        "path_data": {
            "svg_path": maze_data.get("svg_path", ""),
            "solution_path": maze_data.get("solution_path", ""),
            "width": maze_data.get("path_width", 30),
            "complexity": difficulty,
            "maze_type": maze_data.get("maze_type", "grid"),
            "start_point": maze_data.get("start_point", {}),
            "end_point": maze_data.get("end_point", {}),
            "segments": maze_data.get("segments", []),
            "canvas_width": maze_data.get("canvas_width", 600),
            "canvas_height": maze_data.get("canvas_height", 500),
            "control_points": maze_data.get("control_points", []),
        },
        "visual_theme": {
            "background_color": vt["background_color"],
            "decorative_elements": vt["decorative_elements"],
        },
        "preview_svg": svg,
    }

    return labyrinth


def generate_batch(
    client: anthropic.Anthropic,
    age: int,
    difficulty: str,
    themes: list,
    count: int,
    config: dict,
    start_id: int = 1,
) -> list:
    """Generate a batch of labyrinths."""
    results = []
    for i in range(count):
        theme = themes[i % len(themes)]
        lab_id = f"lab_{start_id + i:03d}"
        print(f"  Generating {lab_id}: age={age}, difficulty={difficulty}, theme={theme}...")
        try:
            lab = generate_labyrinth(client, lab_id, age, difficulty, theme, config)
            results.append(lab)
        except Exception as e:
            print(f"  Error generating {lab_id}: {e}")
            continue
    return results


def save_labyrinths(labyrinths: list, output_dir: Path):
    """Save labyrinth JSON files."""
    output_dir.mkdir(parents=True, exist_ok=True)
    for lab in labyrinths:
        # Save JSON (without preview SVG to keep files smaller for bundling)
        lab_for_bundle = {k: v for k, v in lab.items() if k != "preview_svg"}
        json_path = output_dir / f"{lab['id']}.json"
        with open(json_path, "w") as f:
            json.dump(lab_for_bundle, f, indent=2)
        print(f"  Saved: {json_path}")

        # Save preview SVG separately
        svg_dir = output_dir.parent / "svg_previews"
        svg_dir.mkdir(exist_ok=True)
        svg_path = svg_dir / f"{lab['id']}.svg"
        with open(svg_path, "w") as f:
            f.write(lab.get("preview_svg", ""))


def generate_starter_pack(client: anthropic.Anthropic, config: dict, output_dir: Path):
    """Generate the 30-labyrinth starter pack."""
    all_labs = []

    # 10 easy for ages 3-4
    print("\n=== Generating EASY labyrinths (ages 3-4) ===")
    young_themes = config["age_groups"]["young"]["themes"]
    easy_labs = generate_batch(client, 3, "easy", young_themes, 10, config, start_id=1)
    all_labs.extend(easy_labs)

    # 10 medium for ages 4-5
    print("\n=== Generating MEDIUM labyrinths (ages 4-5) ===")
    middle_themes = config["age_groups"]["middle"]["themes"]
    medium_labs = generate_batch(client, 5, "medium", middle_themes, 10, config, start_id=11)
    all_labs.extend(medium_labs)

    # 10 hard for ages 5-6
    print("\n=== Generating HARD labyrinths (ages 5-6) ===")
    older_themes = config["age_groups"]["older"]["themes"]
    hard_labs = generate_batch(client, 6, "hard", older_themes, 10, config, start_id=21)
    all_labs.extend(hard_labs)

    save_labyrinths(all_labs, output_dir)

    # Save manifest
    manifest = {
        "total": len(all_labs),
        "labyrinths": [
            {"id": lab["id"], "age_range": lab["age_range"],
             "difficulty": lab["difficulty"], "theme": lab["theme"],
             "title": lab["title"]}
            for lab in all_labs
        ],
    }
    manifest_path = output_dir / "manifest.json"
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest saved: {manifest_path}")
    print(f"Total labyrinths generated: {len(all_labs)}")


def main():
    parser = argparse.ArgumentParser(description="Generate labyrinth content")
    parser.add_argument("--age", type=int, choices=[3, 4, 5, 6], help="Target age")
    parser.add_argument("--difficulty", choices=["easy", "medium", "hard"], help="Difficulty level")
    parser.add_argument("--theme", type=str, help="Theme name")
    parser.add_argument("--count", type=int, default=1, help="Number to generate")
    parser.add_argument("--starter-pack", action="store_true", help="Generate full 30-labyrinth starter pack")
    parser.add_argument("--output", type=str, default=None, help="Output directory")

    args = parser.parse_args()
    config = load_config()

    output_dir = Path(args.output) if args.output else Path(__file__).parent / "output" / "labyrinths"

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("Error: ANTHROPIC_API_KEY environment variable not set")
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)

    if args.starter_pack:
        generate_starter_pack(client, config, output_dir)
    elif args.age and args.difficulty and args.theme:
        themes = [args.theme]
        labs = generate_batch(client, args.age, args.difficulty, themes, args.count, config)
        save_labyrinths(labs, output_dir)
    else:
        parser.print_help()
        print("\nExamples:")
        print("  python generator.py --starter-pack")
        print("  python generator.py --age 4 --difficulty easy --theme animals --count 2")


if __name__ == "__main__":
    main()
