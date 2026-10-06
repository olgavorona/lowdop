#!/usr/bin/env python3
"""Convert the Fall printable maze data into the iOS app content format."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRINTABLES = ROOT / "content" / "printables" / "fall-mazes" / "json"
APP_CONTENT = ROOT / "LowDopamineLabyrinth" / "LowDopamineLabyrinth" / "Resources" / "Labyrinths"
MANIFEST = APP_CONTENT / "manifest.json"

STORIES = {
    "leaf-pile": 61,
    "apple-basket": 62,
    "corn-maze": 63,
    "pumpkin-patch": 64,
    "acorn-trail": 65,
    "rainy-walk": 66,
}

GOALS = {
    "leaf-pile": ("leaf pile", "Leaf Pile"),
    "apple-basket": ("apple basket", "Apple Basket"),
    "corn-maze": ("corn maze exit", "Maze Exit"),
    "pumpkin-patch": ("big pumpkin", "Big Pumpkin"),
    "acorn-trail": ("squirrel", "Hazel"),
    "rainy-walk": ("umbrella", "Umbrella"),
}

EMOJI = {
    "apple": "🍎",
    "corn": "🌽",
    "pumpkin": "🎃",
    "acorn": "🌰",
    "puddle": "💧",
}

BACKGROUND = {
    "leaf-pile": "#8A4C24",
    "apple-basket": "#7A3D1D",
    "corn-maze": "#6B5A22",
    "pumpkin-patch": "#7A3D1D",
    "acorn-trail": "#5B432A",
    "rainy-walk": "#38566B",
}

STORY_TEXT = {
    "leaf-pile": {
        "setup": "Denny is walking through the autumn woods when he hears a strange crunching sound behind the trees. Golden leaves swirl across the path, and something small is hiding near a giant leaf pile.",
        "instruction": "Help Denny follow the winding path and discover what is rustling in the leaves.",
        "tts": "Denny hears something rustling in the autumn leaves. Help him follow the path to the leaf pile and find out what it is.",
        "completion": "It was only the wind tossing the crunchy leaves into the air. Denny laughed and jumped into the soft golden pile!",
        "question": "What happens to fallen leaves after they land on the ground?",
        "fact": "Fallen leaves slowly break down into tiny pieces. Worms, fungi, and other small decomposers help turn them into rich soil that feeds trees and new plants.",
    },
    "apple-basket": {
        "setup": "A gust of autumn wind has rolled the orchard apples far from their basket. Denny can see them shining between the trees.",
        "instruction": "Help Denny collect the shiny apples and carry them to the basket.",
        "tts": "The apples rolled away in the wind. Help Denny collect them and bring them back to the basket.",
        "completion": "Denny gathered every apple and tucked them safely into the basket!",
        "question": "Why can an apple float in water?",
        "fact": "An apple floats because about one quarter of it is made of tiny air pockets. Those pockets make the whole apple less dense than water, so it stays at the surface.",
    },
    "corn-maze": {
        "setup": "Denny steps into the tall corn maze and hears a soft whisper between the rows. The corn is ready to gather, but the way out is hidden.",
        "instruction": "Help Denny collect the corn and find the gate out of the tall maze.",
        "tts": "Denny hears a whisper in the corn. Help him collect the corn and find the maze exit.",
        "completion": "The whisper came from the dry corn leaves brushing together. Denny collected the corn and found the gate!",
        "question": "What does each strand of corn silk grow into?",
        "fact": "Every strand of corn silk connects to one kernel on the cob. Pollen travels down the silk to help that kernel grow, which is why a cob has so many silky threads.",
    },
    "pumpkin-patch": {
        "setup": "Denny visits the farm to find the biggest pumpkin, but curling vines hide the path. Little pumpkins wait along the way.",
        "instruction": "Help Denny collect the little pumpkins and find the biggest pumpkin in the patch.",
        "tts": "The biggest pumpkin is hiding in the patch. Help Denny collect the little pumpkins and find it.",
        "completion": "Denny collected the little pumpkins and found the biggest, roundest pumpkin in the patch!",
        "question": "Is a pumpkin a fruit or a vegetable?",
        "fact": "A pumpkin is a fruit because it grows from a flower and contains seeds. Pumpkins belong to the same plant family as cucumbers, melons, and squash.",
    },
    "acorn-trail": {
        "setup": "Tap, tap, tap! Denny hears acorns dropping through the quiet autumn woods. At the end of the curled trail, Hazel the squirrel is waiting for help gathering food for winter.",
        "instruction": "Help Denny collect the acorns and carry them along the curled trail to Hazel.",
        "tts": "Hazel the squirrel needs acorns for winter. Help Denny collect them and follow the trail to her.",
        "completion": "Denny brought every acorn to Hazel. She tucked them into her hiding places and thanked Denny with a happy little tail wiggle!",
        "question": "Why do squirrels collect and hide acorns in autumn?",
        "fact": "Squirrels hide acorns in many small places so they have food during winter. They do not find every hidden acorn, and some forgotten ones can sprout into new oak trees.",
    },
    "rainy-walk": {
        "setup": "Plip, plop! A dark cloud drifts over the garden, and puddles begin to form. Denny spots an umbrella on the other side.",
        "instruction": "Help Denny avoid the puddles and reach the umbrella before the rain gets heavier.",
        "tts": "The autumn rain is starting. Help Denny avoid the puddles and reach the umbrella.",
        "completion": "Denny tiptoed around every puddle and reached the umbrella warm and dry!",
        "question": "Why do puddles form after it rains?",
        "fact": "Puddles form when rainwater gathers in low places faster than the ground can soak it up. Sunlight, wind, and warmer air later help the water evaporate.",
    },
}


def convert_item(item: dict) -> dict:
    return {
        "x": item["x"],
        "y": item["y"],
        "emoji": EMOJI.get(item["emoji"], item["emoji"]),
        "on_solution": item.get("on_solution"),
    }


def app_labyrinth(source: dict, slug: str, story: int) -> dict:
    maze = source["maze"]
    goal_type, goal_name = GOALS[slug]
    item_kind = next((item["emoji"] for item in maze.get("items") or []), None)
    avoid_kinds = [item["emoji"] for item in maze.get("avoid_items") or []]
    item_emoji = EMOJI.get(item_kind) if item_kind else " ".join(
        dict.fromkeys(EMOJI.get(kind, kind) for kind in avoid_kinds)
    ) or None
    difficulty = source["difficulty"]
    labyrinth_id = f"denny_{story:03d}_{difficulty}"
    story_text = STORY_TEXT[slug]

    result = {
        "id": labyrinth_id,
        "age_range": "2-6",
        "difficulty": difficulty,
        "theme": "fall",
        "location": "autumn_night",
        "title": source["title"],
        "story_setup": story_text["setup"],
        "instruction": story_text["instruction"],
        "tts_instruction": story_text["tts"],
        "character_start": {
            "type": "baby crab explorer",
            "description": "Denny dressed for an autumn walk",
            "position": "bottom_left",
            "name": "Denny",
            "image_asset": "denny_forest",
        },
        "character_end": {
            "type": goal_type,
            "description": goal_name,
            "position": "top_right",
            "name": goal_name,
            **({"image_asset": "squirrel_forest"} if slug == "acorn-trail" else {}),
        },
        "educational_question": story_text["question"],
        "fun_fact": story_text["fact"],
        "completion_message": story_text["completion"],
        "path_data": {
            "svg_path": maze["svg_path"],
            "solution_path": maze["solution_path"],
            "width": maze["path_width"],
            "complexity": difficulty,
            "maze_type": maze["maze_type"],
            "start_point": maze["start_point"],
            "end_point": maze["end_point"],
            "segments": maze["segments"],
            "canvas_width": maze["canvas_width"],
            "canvas_height": maze["canvas_height"],
            "items": [convert_item(item) for item in maze.get("items") or []] or None,
            "avoid_items": [convert_item(item) for item in maze.get("avoid_items") or []] or None,
        },
        "visual_theme": {
            "background_color": BACKGROUND[slug],
            "decorative_elements": ["leaves", "wind"],
        },
    }
    if source["mode"] in {"collect", "avoid"}:
        result["item_rule"] = source["mode"]
        result["item_emoji"] = item_emoji
    return result


def main() -> None:
    manifest = json.loads(MANIFEST.read_text())
    fall_numbers = set(STORIES.values())
    manifest["labyrinths"] = [
        entry for entry in manifest["labyrinths"]
        if entry.get("story") not in fall_numbers
    ]
    manifest["packs"] = [
        pack for pack in manifest.get("packs", [])
        if pack["id"] not in {"halloween_adventures", "fall_adventures"}
    ]
    manifest["packs"].append({
        "id": "fall_adventures",
        "title": "Fall Adventures",
        "free_stories": 3,
        "stories": list(STORIES.values()),
    })

    for slug, story in STORIES.items():
        for difficulty in ("easy", "medium", "hard"):
            source = json.loads((PRINTABLES / f"{slug}-{difficulty}.json").read_text())
            if slug == "leaf-pile":
                shell_source = json.loads(
                    (PRINTABLES / f"acorn-trail-{difficulty}.json").read_text()
                )
                source["maze"] = {
                    **source["maze"],
                    **shell_source["maze"],
                    "items": [],
                    "avoid_items": [],
                }
            labyrinth = app_labyrinth(source, slug, story)
            labyrinth["audio_instruction"] = f"denny_{story:03d}_instruction.mp3"
            labyrinth["audio_completion"] = f"denny_{story:03d}_completion.mp3"
            labyrinth["audio_answer"] = f"denny_{story:03d}_answer.mp3"
            (APP_CONTENT / f"{labyrinth['id']}.json").write_text(
                json.dumps(labyrinth, indent=2, ensure_ascii=False) + "\n"
            )
            manifest["labyrinths"].append({
                "id": labyrinth["id"],
                "difficulty": difficulty,
                "story": story,
                "theme": "fall",
                "location": "autumn_night",
                "title": source["title"],
            })

    manifest["total"] = len(manifest["labyrinths"])
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"Exported {len(STORIES) * 3} Fall labyrinths")


if __name__ == "__main__":
    main()
