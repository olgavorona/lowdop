"""Generate 'Denny in the Forest' pack — stories 041+ at 3 difficulty levels.

Usage:
    python generate_forest_pack.py                    # all stories, all difficulties
    python generate_forest_pack.py --test             # stories 041-042, medium only
    python generate_forest_pack.py --output path/     # custom output dir
"""

import argparse
import json
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).parent))
from maze_generator import FullMazeGenerator


def load_config() -> dict:
    config_path = Path(__file__).parent / "config.yaml"
    with open(config_path) as f:
        return yaml.safe_load(f)


def load_forest_universe() -> dict:
    path = Path(__file__).parent / "characters" / "denny_forest_universe.json"
    with open(path) as f:
        return json.load(f)


SHAPE_GRID_SCALE = {
    "rect": 1.0,
    "mountain": 1.25,
    "tree": 1.3,
    "triangle": 1.5,
    "diamond": 1.5,
    "circle": 1.8,
}

# ---------------------------------------------------------------------------
# Stories — connected plot arc
# ---------------------------------------------------------------------------
# Denny the explorer crab arrives in Whispering Forest.
# He hears strange sounds and discovers new friends one by one.
# Each story continues from the last.

FOREST_STORIES = {
    "041": {
        "title": "What Is That Noise?",
        "character_end": "maya",
        "location": "forest_entrance",
        "shape": "rect",
        "story_setup": "Denny the explorer has arrived at the edge of Whispering Forest! He hears a mysterious rustling sound coming from inside. Could it be the wind? A wild animal? Denny is curious and a little nervous — but mostly curious.",
        "instruction": "Follow the sounds through the forest and find out what is making that noise!",
        "tts_instruction": "Denny hears something in the forest! Help Denny follow the rustling sounds through the trees to find out what is hiding.",
        "educational_question": "Have you ever heard strange sounds in nature? What do you think makes rustling noises in the forest?",
        "fun_fact": "Forests are full of sounds! Leaves rustling, branches creaking, animals scurrying — a healthy forest is never silent. Scientists can even tell how healthy a forest is by listening to it!",
        "completion_message": "It was Maya! A tiny shy mouse hiding behind a giant mushroom. She was scared of the wind — but not anymore. Denny and Maya are now best friends!",
    },
    "042": {
        "title": "Maya's Secret Path",
        "character_end": "maya",
        "location": "mushroom_clearing",
        "shape": "tree",
        "story_setup": "Maya wants to show Denny her favourite place in the whole forest — a magical clearing full of giant glowing mushrooms! But the path is overgrown and full of twists. Maya knows the way, and Denny follows close behind.",
        "instruction": "Follow Maya's secret path to the magical mushroom clearing!",
        "tts_instruction": "Maya knows a secret path! Help Denny follow Maya through the twisted forest trails to reach the magical mushroom clearing.",
        "educational_question": "Did you know some mushrooms really do glow in the dark? What other things in nature can glow?",
        "fun_fact": "There are over 80 species of bioluminescent fungi — mushrooms that actually glow! They produce a soft green light at night. Scientists are still figuring out exactly why they do it.",
        "completion_message": "Denny and Maya made it to the mushroom clearing! The giant glowing mushrooms light up all around them. Denny thinks the forest might be the most magical place he has ever visited.",
    },
}

FOREST_STORY_POSITIONS = {
    "041": {"start": "bottom_left",  "end": "top_right"},
    "042": {"start": "bottom_right", "end": "top_left"},
}

FOREST_ITEM_COUNTS = {
    "easy": 2, "medium": 4, "hard": 6,
}


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

def generate_forest_variants(output_dir: Path, stories: dict, difficulty_names: list):
    config = load_config()
    difficulty_levels = config["difficulty_levels"]
    universe = load_forest_universe()
    maze_gen = FullMazeGenerator()

    output_dir.mkdir(parents=True, exist_ok=True)
    all_labs = []

    for story_num_str, story in stories.items():
        end_char_key = story["character_end"]
        end_char = universe["characters"][end_char_key]
        denny = universe["characters"]["denny"]
        location = universe["locations"][story["location"]]
        item_rule = story.get("item_rule")
        item_emoji = story.get("item_emoji")
        shape = story["shape"]
        positions = FOREST_STORY_POSITIONS.get(story_num_str, {})
        start_pos = positions.get("start")
        end_pos = positions.get("end")

        for diff_name in difficulty_names:
            variant_id = f"denny_{story_num_str}_{diff_name}"
            diff_config = difficulty_levels[diff_name]
            base_rows, base_cols = diff_config["grid_size"]
            path_width = diff_config["path_width"]
            item_count = FOREST_ITEM_COUNTS[diff_name] if item_rule else 0

            grid_scale = SHAPE_GRID_SCALE.get(shape, 1.0)
            rows = max(base_rows, round(base_rows * grid_scale))
            cols = max(base_cols, round(base_cols * grid_scale))

            label = f"{item_rule} {item_emoji}" if item_rule else "regular"
            print(f"  Generating {variant_id} ({diff_name} {rows}x{cols} {label})...")

            try:
                maze_kwargs = dict(
                    difficulty=diff_name,
                    age=4,
                    shape=shape,
                    canvas_width=600,
                    canvas_height=500,
                    override_rows=rows,
                    override_cols=cols,
                    render_style="corridor",
                    start_position=start_pos,
                    end_position=end_pos,
                )
                if item_rule:
                    maze_kwargs["item_rule"] = item_rule
                    maze_kwargs["item_count"] = item_count
                    maze_kwargs["item_emoji"] = item_emoji
                maze_data = maze_gen.generate_maze(**maze_kwargs)

                bg_color = location["background_color"]
                decorative = location["decorative_elements"]

                variant = {
                    "id": variant_id,
                    "age_range": "3-6",
                    "difficulty": diff_name,
                    "theme": "forest",
                    "location": story["location"],
                    "title": story["title"],
                    "story_setup": story["story_setup"],
                    "instruction": story["instruction"],
                    "tts_instruction": story["tts_instruction"],
                    "character_start": {
                        "type": denny["type"],
                        "description": denny["description"],
                        "position": "bottom_left",
                        "name": "Denny",
                        "image_asset": "denny_forest",
                    },
                    "character_end": {
                        "type": end_char["type"],
                        "description": end_char["description"],
                        "position": "top_right",
                        "name": end_char["name"],
                        "image_asset": f"{end_char_key}_forest",
                    },
                    "educational_question": story["educational_question"],
                    "fun_fact": story["fun_fact"],
                    "completion_message": story["completion_message"],
                    **({"item_rule": item_rule, "item_emoji": item_emoji} if item_rule else {}),
                    "path_data": {
                        "svg_path": maze_data.get("svg_path", ""),
                        "solution_path": maze_data.get("solution_path", ""),
                        "width": path_width,
                        "complexity": diff_name,
                        "maze_type": maze_data.get("maze_type", "corridor_rect"),
                        "start_point": maze_data.get("start_point", {}),
                        "end_point": maze_data.get("end_point", {}),
                        "segments": maze_data.get("segments", []),
                        "canvas_width": maze_data.get("canvas_width", 600),
                        "canvas_height": maze_data.get("canvas_height", 500),
                        "control_points": maze_data.get("control_points", []),
                        "items": maze_data.get("items", []),
                    },
                    "visual_theme": {
                        "background_color": bg_color,
                        "decorative_elements": decorative,
                    },
                    "audio_instruction": f"denny_{story_num_str}_instruction.mp3",
                    "audio_completion": f"denny_{story_num_str}_completion.mp3",
                }

                all_labs.append(variant)
            except Exception as e:
                print(f"  Error generating {variant_id}: {e}")
                import traceback
                traceback.print_exc()
                continue

    # Save individual JSONs
    for lab in all_labs:
        json_path = output_dir / f"{lab['id']}.json"
        with open(json_path, "w") as f:
            json.dump(lab, f, indent=2, ensure_ascii=False)
        print(f"  Saved: {json_path.name}")

    # Update manifest
    manifest_path = output_dir / "manifest.json"
    manifest = {"universe": "denny", "total": 0, "packs": [], "labyrinths": []}
    if manifest_path.exists():
        with open(manifest_path) as f:
            manifest = json.load(f)

    story_ids = set(stories.keys())
    existing_labs = [
        e for e in manifest.get("labyrinths", [])
        if not any(f"denny_{s}_" in e["id"] for s in story_ids)
    ]
    new_entries = [
        {
            "id": lab["id"],
            "difficulty": lab["difficulty"],
            "story": int(lab["id"].split("_")[1]),
            "theme": lab["theme"],
            "location": lab["location"],
            "title": lab["title"],
        }
        for lab in all_labs
    ]
    manifest["labyrinths"] = existing_labs + new_entries
    manifest["total"] = len(manifest["labyrinths"])

    packs = [p for p in manifest.get("packs", []) if p.get("id") != "forest_adventures"]
    packs.append({
        "id": "forest_adventures",
        "title": "Denny in the Forest",
        "free_stories": 0,
        "stories": sorted({int(s) for s in FOREST_STORIES.keys()}),
    })
    manifest["packs"] = packs

    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest: {manifest_path} ({manifest['total']} entries)")
    print(f"Generated: {len(all_labs)} variants")


def main():
    parser = argparse.ArgumentParser(description="Generate 'Denny in the Forest' pack")
    parser.add_argument("--output", type=str, default=None)
    parser.add_argument("--test", action="store_true",
                        help="Generate only stories 041-042 at medium difficulty")
    args = parser.parse_args()

    output_dir = (
        Path(args.output) if args.output
        else Path(__file__).parent / "output" / "labyrinths"
    )

    if args.test:
        stories = {k: v for k, v in FOREST_STORIES.items() if k in ("041", "042")}
        difficulties = ["medium"]
        print(f"TEST MODE — 2 stories × 1 difficulty → {output_dir}")
    else:
        stories = FOREST_STORIES
        difficulties = ["easy", "medium", "hard"]
        print(f"Generating full forest pack → {output_dir}")

    generate_forest_variants(output_dir, stories, difficulties)
    print("\nDone!")


if __name__ == "__main__":
    main()
