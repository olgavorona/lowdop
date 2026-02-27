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
from dotenv import load_dotenv

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


def load_denny_universe() -> dict:
    """Load the Denny character universe data."""
    path = Path(__file__).parent / "characters" / "denny_universe.json"
    with open(path) as f:
        return json.load(f)


def load_story_outlines() -> dict:
    """Load the Denny story outlines."""
    path = Path(__file__).parent / "story_outlines.json"
    with open(path) as f:
        return json.load(f)


def generate_denny_story(
    client: anthropic.Anthropic,
    outline: dict,
    universe: dict,
) -> dict:
    """Call Claude API with denny_story_prompt.txt template for a single story."""
    template_path = Path(__file__).parent / "templates" / "denny_story_prompt.txt"
    with open(template_path) as f:
        template = f.read()

    denny = universe["characters"]["denny"]
    end_char_key = outline["character_end"]
    end_char = universe["characters"][end_char_key]
    location = universe["locations"][outline["location"]]

    prompt = template.format(
        start_character_type=denny["type"],
        start_character_description=denny["description"],
        end_character_name=end_char["name"],
        end_character_type=end_char["type"],
        end_character_description=end_char["description"],
        end_character_key=end_char_key,
        location_name=location["name"],
        location_description=location["description"],
        story_summary=outline["story_summary"],
        age_range=outline["age_range"],
        difficulty=outline["difficulty"],
    )

    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )

    response_text = message.content[0].text.strip()
    if response_text.startswith("```"):
        lines = response_text.split("\n")
        lines = [l for l in lines if not l.startswith("```")]
        response_text = "\n".join(lines)

    return json.loads(response_text)


def generate_denny_pack(client: anthropic.Anthropic, output_dir: Path):
    """Generate all 20 Denny labyrinths from story outlines."""
    universe = load_denny_universe()
    outlines_data = load_story_outlines()
    outlines = outlines_data["outlines"]

    all_labs = []
    maze_gen = FullMazeGenerator()

    # Map difficulty to age for maze generation
    difficulty_age = {"easy": 3, "medium": 5, "hard": 6}

    for outline in outlines:
        lab_id = outline["id"]
        difficulty = outline["difficulty"]
        age = difficulty_age[difficulty]
        rows, cols = outline["grid_size"]
        shape = outline["shape"]
        end_char_key = outline["character_end"]
        end_char = universe["characters"][end_char_key]
        denny = universe["characters"]["denny"]
        location = universe["locations"][outline["location"]]

        print(f"  Generating {lab_id}: {outline['story_summary']}...")

        try:
            # Generate maze with grid size from outline
            maze_data = maze_gen.generate_maze(
                difficulty=difficulty,
                age=age,
                shape=shape,
                canvas_width=600,
                canvas_height=500,
                override_rows=rows,
                override_cols=cols,
            )

            # Generate story via Claude API
            story = generate_denny_story(client, outline, universe)

            # Visual theme from location
            bg_color = location["background_color"]
            decorative = location["decorative_elements"]

            # Generate preview SVG
            svg = maze_gen.to_full_svg(maze_data, bg_color)

            labyrinth = {
                "id": lab_id,
                "age_range": outline["age_range"],
                "difficulty": difficulty,
                "theme": "ocean",
                "location": outline["location"],
                "title": story.get("title", f"Denny's {location['name']} Adventure"),
                "story_setup": story.get("story_setup", ""),
                "instruction": story.get("instruction", ""),
                "tts_instruction": story.get("tts_instruction", ""),
                "character_start": story.get("character_start", {
                    "type": denny["type"],
                    "description": denny["description"],
                    "position": "bottom_left",
                    "name": "Denny",
                    "image_asset": "denny",
                }),
                "character_end": story.get("character_end", {
                    "type": end_char["type"],
                    "description": end_char["description"],
                    "position": "top_right",
                    "name": end_char["name"],
                    "image_asset": end_char_key,
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
                    "background_color": bg_color,
                    "decorative_elements": decorative,
                },
                "preview_svg": svg,
            }

            all_labs.append(labyrinth)
        except Exception as e:
            print(f"  Error generating {lab_id}: {e}")
            continue

    save_labyrinths(all_labs, output_dir)

    # Save manifest
    manifest = {
        "universe": "denny",
        "total": len(all_labs),
        "labyrinths": [
            {"id": lab["id"], "age_range": lab["age_range"],
             "difficulty": lab["difficulty"], "theme": lab["theme"],
             "location": lab["location"], "title": lab["title"]}
            for lab in all_labs
        ],
    }
    manifest_path = output_dir / "manifest.json"
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest saved: {manifest_path}")
    print(f"Total Denny labyrinths generated: {len(all_labs)}")


def generate_difficulty_variants(source_dir: Path, output_dir: Path):
    """Generate 30 labyrinth variants (10 stories x 3 difficulty levels).

    Reuses story content from the first 10 existing JSONs (denny_001-010)
    and generates new maze data at each difficulty level's grid size.
    Audio is shared: all variants reference the base story's audio files.
    """
    config = load_config()
    difficulty_levels = config["difficulty_levels"]
    maze_gen = FullMazeGenerator()

    # Load existing base stories (denny_001 through denny_010)
    base_stories = {}
    for i in range(1, 11):
        base_id = f"denny_{i:03d}"
        json_path = source_dir / f"{base_id}.json"
        if not json_path.exists():
            print(f"  Warning: {json_path} not found, skipping")
            continue
        with open(json_path) as f:
            base_stories[base_id] = json.load(f)

    if not base_stories:
        print("Error: No base story JSONs found")
        return

    output_dir.mkdir(parents=True, exist_ok=True)
    all_labs = []
    difficulty_names = ["easy", "medium", "hard"]

    for base_id, base in base_stories.items():
        story_num = base_id.split("_")[1]  # e.g. "001"
        positions = STORY_POSITIONS.get(story_num, {})
        start_pos = positions.get("start")
        end_pos = positions.get("end")

        for diff_name in difficulty_names:
            variant_id = f"{base_id}_{diff_name}"
            diff_config = difficulty_levels[diff_name]
            rows, cols = diff_config["grid_size"]
            path_width = diff_config["path_width"]

            print(f"  Generating {variant_id} ({diff_name} {rows}x{cols})...")

            try:
                maze_data = maze_gen.generate_maze(
                    difficulty=diff_name,
                    age=4,
                    shape="rect",
                    canvas_width=600,
                    canvas_height=500,
                    override_rows=rows,
                    override_cols=cols,
                    start_position=start_pos,
                    end_position=end_pos,
                )

                # Build variant from base story content + new maze
                variant = {
                    "id": variant_id,
                    "age_range": base.get("age_range", "3-6"),
                    "difficulty": diff_name,
                    "theme": base.get("theme", "ocean"),
                    "location": base.get("location", "sandy_shore"),
                    "title": base["title"],
                    "story_setup": base["story_setup"],
                    "instruction": base["instruction"],
                    "tts_instruction": base.get("tts_instruction", ""),
                    "character_start": base["character_start"],
                    "character_end": base["character_end"],
                    "educational_question": base.get("educational_question", ""),
                    "fun_fact": base.get("fun_fact", ""),
                    "completion_message": base.get("completion_message", "Well done!"),
                    "path_data": {
                        "svg_path": maze_data.get("svg_path", ""),
                        "solution_path": maze_data.get("solution_path", ""),
                        "width": path_width,
                        "complexity": diff_name,
                        "maze_type": maze_data.get("maze_type", "grid"),
                        "start_point": maze_data.get("start_point", {}),
                        "end_point": maze_data.get("end_point", {}),
                        "segments": maze_data.get("segments", []),
                        "canvas_width": maze_data.get("canvas_width", 600),
                        "canvas_height": maze_data.get("canvas_height", 500),
                        "control_points": maze_data.get("control_points", []),
                    },
                    "visual_theme": base.get("visual_theme", {
                        "background_color": "#4A90E2",
                        "decorative_elements": ["stars"],
                    }),
                }

                # Shared audio — reference base story's audio files
                if base.get("audio_instruction"):
                    variant["audio_instruction"] = base["audio_instruction"]
                if base.get("audio_completion"):
                    variant["audio_completion"] = base["audio_completion"]

                all_labs.append(variant)
            except Exception as e:
                print(f"  Error generating {variant_id}: {e}")
                continue

    # Save individual JSONs
    for lab in all_labs:
        json_path = output_dir / f"{lab['id']}.json"
        with open(json_path, "w") as f:
            json.dump(lab, f, indent=2)
        print(f"  Saved: {json_path}")

    # Save manifest
    manifest = {
        "universe": "denny",
        "total": len(all_labs),
        "labyrinths": [
            {"id": lab["id"], "difficulty": lab["difficulty"],
             "theme": lab["theme"], "location": lab["location"],
             "title": lab["title"]}
            for lab in all_labs
        ],
    }
    manifest_path = output_dir / "manifest.json"
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)

    # Generate difficulty_samples.json (first labyrinth's svg_path per level for maze previews)
    samples = {}
    for diff_name in difficulty_names:
        for lab in all_labs:
            if lab["difficulty"] == diff_name:
                samples[diff_name] = lab["path_data"]["svg_path"]
                break
    samples_path = output_dir / "difficulty_samples.json"
    with open(samples_path, "w") as f:
        json.dump(samples, f, indent=2)

    print(f"\nManifest saved: {manifest_path}")
    print(f"Difficulty samples saved: {samples_path}")
    print(f"Total variants generated: {len(all_labs)}")


ADVENTURE_STORIES = {
    "011": {
        "title": "Denny's Shell Collection",
        "character_end": "mama_coral",
        "location": "sandy_shore",
        "item_rule": "collect",
        "item_emoji": "\U0001f41a",
        "shape": "triangle",
        "story_setup": "Mommy Coral asked Denny to collect beautiful shells scattered along the sandy shore. Can you help Denny find them all?",
        "instruction": "Draw a path and collect all the shells along the way to reach Mommy Coral!",
        "tts_instruction": "Help Denny collect all the shells on the beach! Draw a path through the maze and pick up every shell before reaching Mommy Coral.",
        "educational_question": "How many shells did Denny collect? Can you count them?",
        "fun_fact": "Seashells are the homes of soft-bodied animals called mollusks. When the animal grows too big, it makes a bigger shell!",
        "completion_message": "Denny collected all the shells! Mommy Coral is so proud!",
    },
    "012": {
        "title": "Denny's Pearl Dive",
        "character_end": "finn",
        "location": "coral_garden",
        "item_rule": "collect",
        "item_emoji": "\U0001f9aa",
        "shape": "diamond",
        "story_setup": "Shiny pearls are hidden all around the coral garden! Denny and Finn want to collect them all before the tide comes in.",
        "instruction": "Collect all the pearls as you draw a path to reach Finn!",
        "tts_instruction": "Look at all those pearls! Help Denny explore the coral garden and collect every pearl before reaching Finn.",
        "educational_question": "Where do pearls come from? Which animal makes them?",
        "fun_fact": "Pearls are made by oysters! When a tiny grain of sand gets inside, the oyster covers it with smooth layers until it becomes a pearl.",
        "completion_message": "Denny found all the pearls! Finn is amazed!",
    },
    "013": {
        "title": "Denny's Bubble Chase",
        "character_end": "sandy",
        "location": "bubble_lagoon",
        "item_rule": "collect",
        "item_emoji": "\U0001fae7",
        "shape": "circle",
        "story_setup": "Sandy is blowing magical bubbles in the lagoon! Denny wants to catch them all before they float away.",
        "instruction": "Catch all the bubbles as you draw a path to reach Sandy!",
        "tts_instruction": "Sandy is making bubbles! Help Denny catch every bubble in the lagoon as you draw a path to reach Sandy.",
        "educational_question": "What shape are bubbles? Are they always round?",
        "fun_fact": "Bubbles are round because the air inside pushes equally in all directions, making a sphere — the shape with the smallest surface!",
        "completion_message": "Denny caught all of Sandy's bubbles! What fun!",
    },
    "014": {
        "title": "Denny's Coral Bits",
        "character_end": "daddy_reef",
        "location": "sandy_shore",
        "item_rule": "collect",
        "item_emoji": "\U0001fab8",
        "shape": "mountain",
        "story_setup": "Colorful bits of coral have washed up on the shore! Daddy Reef wants Denny to collect them to build a new reef garden.",
        "instruction": "Collect all the coral pieces as you draw a path to Daddy Reef!",
        "tts_instruction": "Daddy Reef needs coral pieces! Help Denny pick up every colorful coral bit on the beach on the way to Daddy Reef.",
        "educational_question": "Did you know coral is alive? What kind of animal is it?",
        "fun_fact": "Coral reefs are home to 25% of all ocean life! Tiny animals called polyps build the reef by creating hard skeletons around themselves.",
        "completion_message": "Denny collected all the coral! Daddy Reef will build an amazing reef garden!",
    },
    "015": {
        "title": "Denny's Starfish Search",
        "character_end": "stella",
        "location": "starfish_cove",
        "item_rule": "collect",
        "item_emoji": "\u2b50",
        "shape": "tree",
        "story_setup": "Stella lost her favorite star-shaped treasures in the cove! Denny wants to help find them all.",
        "instruction": "Collect all the stars to help Stella as you find your way to her!",
        "tts_instruction": "Stella needs your help! Draw a path through the cove and collect all the lost stars before reaching Stella.",
        "educational_question": "How many arms does a starfish have? Can they grow new ones?",
        "fun_fact": "Starfish can regrow their arms if one breaks off! Some starfish have more than 5 arms — the sun star can have up to 40!",
        "completion_message": "Denny found all of Stella's stars! She's so happy!",
    },
    "016": {
        "title": "Denny's Clam Hunt",
        "character_end": "bubbles",
        "location": "coral_garden",
        "item_rule": "collect",
        "item_emoji": "\U0001f9aa",
        "shape": "triangle",
        "story_setup": "Bubbles spotted tasty clams hiding in the coral garden! Denny is helping gather them for a yummy seafood feast.",
        "instruction": "Collect all the clams as you draw a path to reach Bubbles!",
        "tts_instruction": "Yummy clams everywhere! Help Denny find every clam hiding in the coral garden on the way to Bubbles.",
        "educational_question": "How do clams eat? Do they have mouths?",
        "fun_fact": "Clams filter water to eat! A single clam can clean up to 50 gallons of water every day. That helps keep the ocean clean!",
        "completion_message": "Denny found all the clams! Bubbles is ready for a feast!",
    },
    "017": {
        "title": "Denny's Seaweed Harvest",
        "character_end": "shelly",
        "location": "kelp_forest",
        "item_rule": "collect",
        "item_emoji": "\U0001f33f",
        "shape": "diamond",
        "story_setup": "Shelly needs seaweed for a special recipe! Denny is helping gather the freshest pieces from the kelp forest.",
        "instruction": "Collect all the seaweed as you make your way to Shelly!",
        "tts_instruction": "Shelly needs seaweed for cooking! Help Denny pick up every piece of seaweed in the kelp forest on the way to Shelly.",
        "educational_question": "Do you know any foods that are made with seaweed?",
        "fun_fact": "Seaweed is a superfood! It's used to make sushi wraps, ice cream, and even toothpaste. Kelp can grow up to 2 feet per day!",
        "completion_message": "Denny gathered all the seaweed! Shelly can make her special recipe now!",
    },
    "018": {
        "title": "Denny's Kelp Harvest",
        "character_end": "ollie",
        "location": "kelp_forest",
        "item_rule": "collect",
        "item_emoji": "\U0001f96c",
        "shape": "circle",
        "story_setup": "Ollie needs fresh kelp leaves for a special soup! Denny is swimming through the forest to gather the best ones.",
        "instruction": "Collect all the kelp leaves as you draw a path to reach Ollie!",
        "tts_instruction": "Ollie needs kelp for soup! Help Denny swim through the forest and collect every kelp leaf before reaching Ollie.",
        "educational_question": "What is kelp? Is it a plant or something else?",
        "fun_fact": "Giant kelp can grow up to 2 feet per day, making it one of the fastest growing things on Earth! Sea otters wrap themselves in kelp to sleep.",
        "completion_message": "Denny gathered all the kelp! Ollie's soup will be delicious!",
    },
    "019": {
        "title": "Denny's Treasure Hunt",
        "character_end": "finn",
        "location": "shipwreck_playground",
        "item_rule": "collect",
        "item_emoji": "\U0001f48e",
        "shape": "mountain",
        "story_setup": "Finn discovered sparkly gems near the old shipwreck! He and Denny are on a treasure hunt to collect them all.",
        "instruction": "Collect all the gems on your way to meet Finn at the shipwreck!",
        "tts_instruction": "Treasure hunt! Help Denny collect every sparkling gem hidden around the shipwreck before meeting Finn.",
        "educational_question": "If you found a treasure chest, what would you wish was inside?",
        "fun_fact": "Real treasure has been found in shipwrecks! The Atocha shipwreck had gold and emeralds worth over 400 million dollars!",
        "completion_message": "Denny found all the treasure! What an amazing adventure with Finn!",
    },
    "020": {
        "title": "Denny's Coin Collection",
        "character_end": "pearl",
        "location": "bubble_lagoon",
        "item_rule": "collect",
        "item_emoji": "\U0001fa99",
        "shape": "rect",
        "story_setup": "Old pirate coins have sunk to the bottom of the lagoon! Denny and Pearl are on a mission to collect them all.",
        "instruction": "Collect all the coins as you draw a path to reach Pearl!",
        "tts_instruction": "Pirate treasure! Help Denny pick up every gold coin in the lagoon on the way to Pearl.",
        "educational_question": "If you found pirate treasure, what would you buy with it?",
        "fun_fact": "Real pirate coins were called pieces of eight! They were made of silver and could be cut into eight pieces to make change.",
        "completion_message": "Denny collected all the coins! Pearl and Denny are rich!",
    },
}

# Item counts per difficulty for adventure mazes (all collect)
ADVENTURE_ITEM_COUNTS = {
    "easy": 2, "medium": 4, "hard": 6,
}


# Start/end positions per story — start never at top to avoid iOS curtain gesture
# Grid scale factors for shaped mazes — compensates for mask cell loss
# so effective cell count stays appropriate for the difficulty level.
SHAPE_GRID_SCALE = {
    "rect": 1.0,
    "mountain": 1.25,
    "tree": 1.3,
    "triangle": 1.5,
    "diamond": 1.5,
    "circle": 1.8,
}

STORY_POSITIONS = {
    "001": {"start": "bottom_left", "end": "top_right"},
    "002": {"start": "bottom_right", "end": "top_left"},
    "003": {"start": "bottom_right", "end": "top_left"},
    "004": {"start": "bottom_left", "end": "top_right"},
    "005": {"start": "bottom_left", "end": "top_right"},
    "006": {"start": "bottom_right", "end": "top_left"},
    "007": {"start": "bottom_left", "end": "top_right"},
    "008": {"start": "bottom_right", "end": "top_left"},
    "009": {"start": "bottom_left", "end": "top_right"},
    "010": {"start": "bottom_right", "end": "top_left"},
    "011": {"start": "bottom_left", "end": "top_right"},
    "012": {"start": "bottom_left", "end": "top_right"},
    "013": {"start": "bottom_right", "end": "top_left"},
    "014": {"start": "bottom_right", "end": "top_left"},
    "015": {"start": "bottom_left", "end": "top_right"},
    "016": {"start": "bottom_right", "end": "top_left"},
    "017": {"start": "bottom_left", "end": "top_right"},
    "018": {"start": "bottom_left", "end": "top_right"},
    "019": {"start": "bottom_left", "end": "top_right"},
    "020": {"start": "bottom_right", "end": "top_left"},
}


def generate_adventure_variants(output_dir: Path):
    """Generate 30 adventure labyrinth variants (10 stories x 3 difficulty levels).

    Stories 011-020 with corridor-style mazes and collect items.
    """
    config = load_config()
    difficulty_levels = config["difficulty_levels"]
    universe = load_denny_universe()
    maze_gen = FullMazeGenerator()

    output_dir.mkdir(parents=True, exist_ok=True)
    all_labs = []
    difficulty_names = ["easy", "medium", "hard"]

    for story_num_str, story in ADVENTURE_STORIES.items():
        end_char_key = story["character_end"]
        end_char = universe["characters"][end_char_key]
        denny = universe["characters"]["denny"]
        location = universe["locations"][story["location"]]
        item_rule = story["item_rule"]
        item_emoji = story["item_emoji"]
        shape = story["shape"]
        positions = STORY_POSITIONS.get(story_num_str, {})
        start_pos = positions.get("start")
        end_pos = positions.get("end")

        for diff_name in difficulty_names:
            variant_id = f"denny_{story_num_str}_{diff_name}"
            diff_config = difficulty_levels[diff_name]
            base_rows, base_cols = diff_config["grid_size"]
            path_width = diff_config["path_width"]
            item_count = ADVENTURE_ITEM_COUNTS[diff_name]

            # Scale up grid for shaped mazes to compensate for mask cell loss
            grid_scale = SHAPE_GRID_SCALE.get(shape, 1.0)
            rows = max(base_rows, round(base_rows * grid_scale))
            cols = max(base_cols, round(base_cols * grid_scale))

            print(f"  Generating {variant_id} ({diff_name} {rows}x{cols} {item_rule} {item_emoji})...")

            try:
                maze_data = maze_gen.generate_maze(
                    difficulty=diff_name,
                    age=4,
                    shape=shape,
                    canvas_width=600,
                    canvas_height=500,
                    override_rows=rows,
                    override_cols=cols,
                    render_style="corridor",
                    item_rule=item_rule,
                    item_count=item_count,
                    item_emoji=item_emoji,
                    start_position=start_pos,
                    end_position=end_pos,
                )

                bg_color = location["background_color"]
                decorative = location["decorative_elements"]

                variant = {
                    "id": variant_id,
                    "age_range": "3-6",
                    "difficulty": diff_name,
                    "theme": "ocean",
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
                        "image_asset": "denny",
                    },
                    "character_end": {
                        "type": end_char["type"],
                        "description": end_char["description"],
                        "position": "top_right",
                        "name": end_char["name"],
                        "image_asset": end_char_key,
                    },
                    "educational_question": story["educational_question"],
                    "fun_fact": story["fun_fact"],
                    "completion_message": story["completion_message"],
                    "item_rule": item_rule,
                    "item_emoji": item_emoji,
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
        print(f"  Saved: {json_path}")

    # Append adventure entries to manifest (merge with existing if present)
    manifest_path = output_dir / "manifest.json"
    manifest = {"universe": "denny", "total": 0, "labyrinths": []}
    if manifest_path.exists():
        with open(manifest_path) as f:
            manifest = json.load(f)

    # Remove any old adventure entries (011-020) before appending fresh ones
    existing = [e for e in manifest["labyrinths"] if not any(
        f"denny_{s}_" in e["id"] for s in ADVENTURE_STORIES.keys()
    )]
    new_entries = [
        {"id": lab["id"], "difficulty": lab["difficulty"],
         "theme": lab["theme"], "location": lab["location"],
         "title": lab["title"]}
        for lab in all_labs
    ]
    manifest["labyrinths"] = existing + new_entries
    manifest["total"] = len(manifest["labyrinths"])

    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest updated: {manifest_path} ({manifest['total']} entries)")
    print(f"Total adventure variants generated: {len(all_labs)}")


def generate_audio_for_labyrinths(labyrinth_dir: Path):
    """Generate ElevenLabs TTS audio for all labyrinths in a directory."""
    elevenlabs_key = os.environ.get("ELEVENLABS_API_KEY")
    if not elevenlabs_key:
        print("Error: ELEVENLABS_API_KEY environment variable not set")
        sys.exit(1)

    try:
        import requests
    except ImportError:
        print("Error: requests package not installed. Run: pip install requests")
        sys.exit(1)

    audio_dir = labyrinth_dir / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)

    # ElevenLabs API settings — Charlotte voice (warm, kid-friendly)
    voice_id = os.environ.get("ELEVENLABS_VOICE_ID", "XB0fDUnXU5powFXDhCwa")
    api_url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    headers = {
        "xi-api-key": elevenlabs_key,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    }

    json_files = sorted(labyrinth_dir.glob("denny_*.json"))
    print(f"\nGenerating audio for {len(json_files)} labyrinths...")

    # Track already-generated shared audio to avoid duplicates across difficulty variants
    generated_audio: set[str] = set()

    for json_path in json_files:
        with open(json_path) as f:
            lab = json.load(f)

        lab_id = lab["id"]

        # Use audio filename from JSON if set (shared across difficulty levels),
        # otherwise construct from lab_id
        instruction_file = lab.get("audio_instruction") or f"{lab_id}_instruction.mp3"
        instruction_path = audio_dir / instruction_file
        if not instruction_path.exists() and instruction_file not in generated_audio:
            tts_text = lab.get("tts_instruction", "")
            if tts_text:
                print(f"  Generating instruction audio: {instruction_file}...")
                _call_elevenlabs(api_url, headers, tts_text, instruction_path)
                generated_audio.add(instruction_file)
            else:
                instruction_file = None
        else:
            print(f"  Skipping {instruction_file} (already exists)")

        completion_file = lab.get("audio_completion") or f"{lab_id}_completion.mp3"
        completion_path = audio_dir / completion_file
        if not completion_path.exists() and completion_file not in generated_audio:
            completion_text = f"{lab.get('completion_message', '')} {lab.get('educational_question', '')}"
            if completion_text.strip():
                print(f"  Generating completion audio: {completion_file}...")
                _call_elevenlabs(api_url, headers, completion_text, completion_path)
                generated_audio.add(completion_file)
            else:
                completion_file = None
        else:
            print(f"  Skipping {completion_file} (already exists)")

        # Update JSON with audio filenames if not already set
        updated = False
        if instruction_file and lab.get("audio_instruction") != instruction_file:
            lab["audio_instruction"] = instruction_file
            updated = True
        if completion_file and lab.get("audio_completion") != completion_file:
            lab["audio_completion"] = completion_file
            updated = True

        if updated:
            with open(json_path, "w") as f:
                json.dump(lab, f, indent=2)
            print(f"  Updated {json_path.name} with audio fields")

    print(f"\nAudio generation complete. Files saved to: {audio_dir}")


def _call_elevenlabs(api_url: str, headers: dict, text: str, output_path: Path):
    """Call ElevenLabs API to generate speech audio."""
    import requests

    payload = {
        "text": text,
        "model_id": "eleven_turbo_v2_5",
        "voice_settings": {
            "stability": 0.6,
            "similarity_boost": 0.75,
        },
    }

    try:
        response = requests.post(api_url, json=payload, headers=headers, timeout=30)
        response.raise_for_status()
        with open(output_path, "wb") as f:
            f.write(response.content)
    except Exception as e:
        print(f"    Error generating audio: {e}")


def main():
    parser = argparse.ArgumentParser(description="Generate labyrinth content")
    parser.add_argument("--age", type=int, choices=[3, 4, 5, 6], help="Target age")
    parser.add_argument("--difficulty", choices=["easy", "medium", "hard"], help="Difficulty level")
    parser.add_argument("--theme", type=str, help="Theme name")
    parser.add_argument("--count", type=int, default=1, help="Number to generate")
    parser.add_argument("--starter-pack", action="store_true", help="Generate full 30-labyrinth starter pack")
    parser.add_argument("--universe", type=str, choices=["denny"], help="Generate labyrinths for a character universe")
    parser.add_argument("--output", type=str, default=None, help="Output directory")
    parser.add_argument("--generate-audio", action="store_true", help="Generate ElevenLabs TTS audio for existing labyrinths")
    parser.add_argument("--difficulty-variants", action="store_true", help="Generate 30 difficulty variants from first 10 stories")
    parser.add_argument("--adventure-variants", action="store_true", help="Generate 30 adventure maze variants (stories 011-020)")
    parser.add_argument("--source-dir", type=str, default=None, help="Source directory with base story JSONs (for --difficulty-variants)")

    args = parser.parse_args()
    load_dotenv()
    config = load_config()

    output_dir = Path(args.output) if args.output else Path(__file__).parent / "output" / "labyrinths"

    if args.adventure_variants:
        generate_adventure_variants(output_dir)
        return

    if args.difficulty_variants:
        source_dir = Path(args.source_dir) if args.source_dir else output_dir
        generate_difficulty_variants(source_dir, output_dir)
        return

    if args.generate_audio:
        generate_audio_for_labyrinths(output_dir)
        return

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("Error: ANTHROPIC_API_KEY environment variable not set")
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)

    if args.universe == "denny":
        generate_denny_pack(client, output_dir)
    elif args.starter_pack:
        generate_starter_pack(client, config, output_dir)
    elif args.age and args.difficulty and args.theme:
        themes = [args.theme]
        labs = generate_batch(client, args.age, args.difficulty, themes, args.count, config)
        save_labyrinths(labs, output_dir)
    else:
        parser.print_help()
        print("\nExamples:")
        print("  python generator.py --starter-pack")
        print("  python generator.py --universe denny")
        print("  python generator.py --age 4 --difficulty easy --theme animals --count 2")
        print("  python generator.py --generate-audio --output path/to/labyrinths")


if __name__ == "__main__":
    main()
