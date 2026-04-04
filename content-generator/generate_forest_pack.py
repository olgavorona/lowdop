"""Generate 'Denny in the Forest' pack — stories 041+ at 3 difficulty levels.

Usage:
    python generate_forest_pack.py                    # all stories, all difficulties
    python generate_forest_pack.py --test             # stories 041-043, medium only
    python generate_forest_pack.py --output path/     # custom output dir

Maze types (one per story):
    041 — organic  : simple winding bezier path, no dead ends (easiest)
    042 — corridor : thick corridor strokes through a tree-shaped grid
    043 — walls    : traditional wall-based maze at the babbling brook
"""

import argparse
import json
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).parent))
from maze_generator import FullMazeGenerator, OrganicPathGenerator


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
#
# maze_style controls the generator:
#   "organic"   → OrganicPathGenerator (simple curved path, no dead ends)
#   "corridor"  → render_style="corridor" (thick corridor strokes)
#   "walls"     → render_style="walls"   (traditional wall-based maze)

FOREST_STORIES = {
    "041": {
        "title": "What Is That Noise?",
        "character_end": "maya",
        "location": "forest_entrance",
        "shape": "rect",
        "maze_style": "organic",
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
        "maze_style": "corridor",
        "story_setup": "Maya wants to show Denny her favourite place in the whole forest — a magical clearing full of giant glowing mushrooms! But the path is overgrown and full of twists. Maya knows the way, and Denny follows close behind.",
        "instruction": "Follow Maya's secret path to the magical mushroom clearing!",
        "tts_instruction": "Maya knows a secret path! Help Denny follow Maya through the twisted forest trails to reach the magical mushroom clearing.",
        "educational_question": "Did you know some mushrooms really do glow in the dark? What other things in nature can glow?",
        "fun_fact": "There are over 80 species of bioluminescent fungi — mushrooms that actually glow! They produce a soft green light at night. Scientists are still figuring out exactly why they do it.",
        "completion_message": "Denny and Maya made it to the mushroom clearing! The giant glowing mushrooms light up all around them. Denny thinks the forest might be the most magical place he has ever visited.",
    },
    "043": {
        "title": "The Babbling Brook",
        "character_end": "maya",
        "location": "babbling_brook",
        "shape": "rect",
        "maze_style": "walls",
        "story_setup": "Denny and Maya hear the sound of water! There is a brook nearby with shiny stepping stones. But the path through the trees is tricky — full of twists and turns. Can they find the way through?",
        "instruction": "Help Denny and Maya find the path through the trees to reach the babbling brook!",
        "tts_instruction": "There's a brook with stepping stones ahead! Help Denny and Maya find the right path through the forest to reach the water.",
        "educational_question": "How do animals cross streams? Some jump on stones, some swim — what else can you think of?",
        "fun_fact": "Stepping stones in streams help animals and people cross without getting wet. Frogs, otters, and even deer use them! Small streams are some of the most important habitats in a forest.",
        "completion_message": "They found it! The babbling brook sparkles in the sunlight. Denny sees frogs jumping between the lily pads. Maya says this is her second favourite place in the forest.",
    },
}

FOREST_STORY_POSITIONS = {
    "041": {"start": "bottom_left",  "end": "top_right"},
    "042": {"start": "bottom_right", "end": "top_left"},
    "043": {"start": "bottom_left",  "end": "top_right"},
}

ORGANIC_GRID = {
    # (cols, rows) of the coarse grid used for the labyrinth Hamiltonian path.
    # More cells = more twists = harder to follow.
    "easy":   (5, 4),   # 20 cells
    "medium": (7, 5),   # 35 cells
    "hard":   (9, 6),   # 54 cells
}

FOREST_ITEM_COUNTS = {
    "easy": 2, "medium": 4, "hard": 6,
}


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

def generate_organic(diff_name: str, canvas_width: int, canvas_height: int) -> dict:
    """Generate a labyrinth-style path and normalise to the shared maze_data format."""
    grid_cols, grid_rows = ORGANIC_GRID[diff_name]
    gen = OrganicPathGenerator(width=canvas_width, height=canvas_height, path_width=35)
    data = gen.generate(style="labyrinth", grid_cols=grid_cols, grid_rows=grid_rows)
    return {
        "svg_path": data["svg_path"],
        "solution_path": "",          # organic = single path, no separate solution
        "width": data["path_width"],
        "complexity": diff_name,
        "maze_type": "organic",
        "start_point": data["start_point"],
        "end_point": data["end_point"],
        "segments": data["segments"],
        "canvas_width": data["canvas_width"],
        "canvas_height": data["canvas_height"],
        "control_points": data.get("control_points", []),
        "items": [],
    }


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
        maze_style = story["maze_style"]
        positions = FOREST_STORY_POSITIONS.get(story_num_str, {})
        start_pos = positions.get("start")
        end_pos = positions.get("end")

        for diff_name in difficulty_names:
            variant_id = f"denny_{story_num_str}_{diff_name}"
            diff_config = difficulty_levels[diff_name]
            base_rows, base_cols = diff_config["grid_size"]
            path_width = diff_config["path_width"]

            print(f"  Generating {variant_id} ({diff_name} [{maze_style}])...")

            try:
                if maze_style == "organic":
                    maze_data = generate_organic(diff_name, canvas_width=600, canvas_height=500)
                else:
                    grid_scale = SHAPE_GRID_SCALE.get(shape, 1.0)
                    rows = max(base_rows, round(base_rows * grid_scale))
                    cols = max(base_cols, round(base_cols * grid_scale))
                    item_count = FOREST_ITEM_COUNTS[diff_name] if item_rule else 0

                    maze_kwargs = dict(
                        difficulty=diff_name,
                        age=4,
                        shape=shape,
                        canvas_width=600,
                        canvas_height=500,
                        override_rows=rows,
                        override_cols=cols,
                        render_style=maze_style if maze_style == "corridor" else "walls",
                        start_position=start_pos,
                        end_position=end_pos,
                    )
                    if item_rule:
                        maze_kwargs["item_rule"] = item_rule
                        maze_kwargs["item_count"] = item_count
                        maze_kwargs["item_emoji"] = item_emoji
                    raw = maze_gen.generate_maze(**maze_kwargs)
                    maze_data = {
                        "svg_path": raw.get("svg_path", ""),
                        "solution_path": raw.get("solution_path", ""),
                        "width": path_width,
                        "complexity": diff_name,
                        "maze_type": raw.get("maze_type", "grid"),
                        "start_point": raw.get("start_point", {}),
                        "end_point": raw.get("end_point", {}),
                        "segments": raw.get("segments", []),
                        "canvas_width": raw.get("canvas_width", 600),
                        "canvas_height": raw.get("canvas_height", 500),
                        "control_points": raw.get("control_points", []),
                        "items": raw.get("items", []),
                    }

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
                    **({
                        "item_rule": item_rule,
                        "item_emoji": item_emoji,
                    } if item_rule else {}),
                    "path_data": maze_data,
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
                        help="Generate stories 041-043 at medium difficulty only")
    args = parser.parse_args()

    output_dir = (
        Path(args.output) if args.output
        else Path(__file__).parent / "output" / "labyrinths"
    )

    if args.test:
        stories = FOREST_STORIES
        difficulties = ["medium"]
        print(f"TEST MODE — {len(stories)} stories × 1 difficulty → {output_dir}")
    else:
        stories = FOREST_STORIES
        difficulties = ["easy", "medium", "hard"]
        print(f"Generating full forest pack → {output_dir}")

    generate_forest_variants(output_dir, stories, difficulties)
    print("\nDone!")


if __name__ == "__main__":
    main()
