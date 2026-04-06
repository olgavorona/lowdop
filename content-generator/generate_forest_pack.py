#!/usr/bin/env python3
"""Generate the forest pack using Claude's original Maya-led style as the base.

Stories 041-044 are restored from the original forest generator. Stories 045-060
continue the same richer maze style with connected forest arcs and a final
leaf-shaped organic path.
"""

import argparse
import json
import random
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).parent))
from maze_generator import FullMazeGenerator, OrganicPathGenerator


def load_config() -> dict:
    config_path = Path(__file__).parent / "config.yaml"
    with open(config_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_forest_universe() -> dict:
    path = Path(__file__).parent / "characters" / "denny_forest_universe.json"
    with open(path, encoding="utf-8") as f:
        return json.load(f)


SHAPE_GRID_SCALE = {
    "rect": 1.0,
    "mountain": 1.25,
    "tree": 1.3,
    "triangle": 1.5,
    "diamond": 1.5,
    "circle": 1.8,
}

ORGANIC_PETALS = {
    "easy": 5,
    "medium": 10,
    "hard": 20,
}

FOREST_ITEM_COUNTS = {
    "easy": 2,
    "medium": 4,
    "hard": 6,
}

LEAF_WIDTHS = {
    "easy": 34,
    "medium": 24,
    "hard": 15,
}

LEAF_ITEM_COUNTS = {
    "easy": 5,
    "medium": 8,
    "hard": 12,
}

FOREST_STORIES = {
    "041": {
        "title": "What Is That Noise?",
        "character_end": "maya",
        "location": "forest_entrance",
        "shape": "rect",
        "maze_style": "walls",
        "story_setup": "Denny the explorer has arrived at the edge of Whispering Forest. A mysterious rustling sound comes from deep inside the bushes, but he cannot tell what is making it. Help Denny follow the winding path through the forest and discover who is hiding there.",
        "instruction": "Find the path through the bushes and discover who is making the noise!",
        "tts_instruction": "Something is rustling in the bushes. Help Denny follow the path through the forest and find out who is making that noise.",
        "educational_question": "Have you ever heard strange sounds in nature? What do you think makes rustling noises in the forest?",
        "fun_fact": "Forests are full of sounds! Leaves rustling, branches creaking, animals scurrying — a healthy forest is never silent. Scientists can even tell how healthy a forest is by listening to it!",
        "completion_message": "It was Maya. A tiny shy mouse peeked out from behind the bushes and smiled at Denny. So that was the little rustling sound all along.",
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
        "title": "Flowers for Maya",
        "character_end": "maya",
        "location": "babbling_brook",
        "shape": "rect",
        "maze_style": "organic",
        "item_rule": "collect",
        "item_emoji": "🌸",
        "story_setup": "Maya spots bright wildflowers growing beside the babbling brook and wants to gather a pretty little bouquet. The brookside path twists through the trees, and Denny helps collect the flowers along the way.",
        "instruction": "Collect all the flowers and bring them to Maya by the brook!",
        "tts_instruction": "Bright flowers are blooming beside the brook. Help Denny collect every flower and bring them to Maya.",
        "educational_question": "Why do flowers grow well near streams and sunny forest edges?",
        "fun_fact": "Flowers need sunlight, water, and healthy soil to grow. Near streams, the ground often stays damp enough to help many plants bloom.",
        "completion_message": "Denny gathered every flower and brought them safely to Maya. The little bouquet looked beautiful beside the sparkling brook.",
    },
    "044": {
        "title": "Watch Out for the Owls!",
        "character_end": "maya",
        "location": "owl_hollow",
        "shape": "rect",
        "maze_style": "walls",
        "item_rule": "avoid",
        "item_emoji": "🦉",
        "story_setup": "Denny and Maya have wandered into the oldest part of the forest — the Owl Hollow, where wise owls sleep during the day in their favourite trees. Denny must sneak through without waking a single one!",
        "instruction": "Sneak past the sleeping owls to reach Maya — don't touch them!",
        "tts_instruction": "Owls are sleeping on the path! Find a way around them to reach Maya at the other side.",
        "educational_question": "Why do owls sleep during the day? Can you name other animals that are awake at night?",
        "fun_fact": "Owls have special soft feathers that let them fly almost silently. But they have super-sharp hearing — even a tiny sound can wake them! Owls can turn their heads almost all the way around to look for sounds.",
        "completion_message": "Denny tiptoed all the way through without waking a single owl! Maya claps quietly so she doesn't wake them either. What a clever little crab!",
    },
    "045": {
        "title": "Tracks to the Fox Den",
        "character_end": "fox",
        "location": "fox_den",
        "shape": "diamond",
        "maze_style": "walls",
        "story_setup": "While exploring with Maya, Denny spots tiny paw prints in the pine needles. They lead to Finn the fox cub, who is peeking out from beside a hollow log. Denny follows the tracks to meet a brand-new forest friend for the first time.",
        "instruction": "Follow the tracks through the maze and meet Finn the fox cub!",
        "tts_instruction": "Tiny fox tracks lead through the forest. Help Denny follow the right path to meet Finn the fox cub for the first time.",
        "educational_question": "How do animals leave clues behind in the forest? What kinds of tracks have you seen?",
        "fun_fact": "Foxes have very good hearing. They can listen for small animals moving under leaves and even under snow.",
        "completion_message": "Denny found Finn curled beside a hollow log. Finn's tail gave a happy little swish when he met Denny and Maya for the very first time.",
    },
    "046": {
        "title": "Blueberries for Finn",
        "character_end": "fox",
        "location": "berry_bush",
        "shape": "circle",
        "maze_style": "walls",
        "item_rule": "collect",
        "item_emoji": "🫐",
        "story_setup": "Finn wants to make a berry snack to share with Maya and Denny. The berry patch is full of twisting paths and ripe blueberries waiting to be gathered.",
        "instruction": "Collect all the blueberries and bring them to Finn!",
        "tts_instruction": "Blueberries are hiding all along the path. Help Denny collect every berry before reaching Finn.",
        "educational_question": "Which animals in the forest like berries? Can people and animals eat the same berries?",
        "fun_fact": "Many forest animals eat berries, but some berries are only safe for animals. People should only eat berries when a grown-up knows they are safe.",
        "completion_message": "Every blueberry made it safely to Finn. He shared the berry snack with Maya and Denny under the pine tree.",
    },
    "047": {
        "title": "Sneak Past the Bees",
        "character_end": "fox",
        "location": "oak_tree",
        "shape": "mountain",
        "maze_style": "walls",
        "item_rule": "avoid",
        "item_emoji": "🐝",
        "story_setup": "A buzzing honey tree stands between Denny and Finn. The bees are busy at work, and Denny must move carefully so he doesn't bump into them.",
        "instruction": "Find a quiet path past the bees to reach Finn!",
        "tts_instruction": "The bees are busy near the honey tree. Help Denny find the safe path past them to Finn.",
        "educational_question": "Why are bees important in a forest or garden?",
        "fun_fact": "Bees help plants make seeds and fruit by moving pollen from flower to flower. That is called pollination.",
        "completion_message": "Denny tiptoed safely past the bees. Finn cheered from the far side of the oak roots and showed Denny the way onward.",
    },
    "048": {
        "title": "Ribbits by the Brook",
        "character_end": "frog",
        "location": "babbling_brook",
        "shape": "rect",
        "maze_style": "walls",
        "story_setup": "After saying goodbye to Finn, Denny hears cheerful ribbits bouncing off the water. On the far side of the brook, Pip the frog is calling hello. Denny follows the brookside path to meet Pip for the first time.",
        "instruction": "Find the path through the brookside maze and meet Pip the frog!",
        "tts_instruction": "Pip the frog is calling from the brook. Help Denny find the right path through the forest to meet Pip for the first time.",
        "educational_question": "Why do frogs like wet places so much?",
        "fun_fact": "Frogs can breathe through their skin when it stays wet, which is one reason they like ponds and streams.",
        "completion_message": "Denny found Pip beside the stepping stones. Pip gave one giant ribbit of welcome when he met Denny for the very first time.",
    },
    "049": {
        "title": "Pebbles for Pip",
        "character_end": "frog",
        "location": "waterfall",
        "shape": "circle",
        "maze_style": "walls",
        "item_rule": "collect",
        "item_emoji": "🪨",
        "story_setup": "Pip is building a tiny splash pool near the hidden waterfall. Denny gathers smooth pebbles from the winding path to help line the little pool.",
        "instruction": "Collect all the pebbles and bring them to Pip!",
        "tts_instruction": "Smooth pebbles are scattered near the waterfall. Help Denny collect every pebble before reaching Pip.",
        "educational_question": "Why are stones in streams often smooth and round?",
        "fun_fact": "Running water slowly rubs rough stones against each other and makes them smoother over time.",
        "completion_message": "The pebbles made Pip's little splash pool sparkle. The waterfall mist felt cool and wonderful on Denny's shell.",
    },
    "050": {
        "title": "Watch Out for the Snakes",
        "character_end": "frog",
        "location": "babbling_brook",
        "shape": "triangle",
        "maze_style": "walls",
        "item_rule": "avoid",
        "item_emoji": "🐍",
        "story_setup": "Tall reeds sway beside the brook, and sleepy garden snakes are warming themselves on the path. Denny must slip by carefully to reach Pip.",
        "instruction": "Sneak around the snakes and reach Pip safely!",
        "tts_instruction": "Some sleepy snakes are resting by the reeds. Help Denny find a careful path around them to Pip.",
        "educational_question": "How do snakes move without legs?",
        "fun_fact": "Snakes push against the ground with their scales and muscles to slither forward in smooth curves.",
        "completion_message": "Denny glided around every sleepy snake. Pip clapped his little webbed feet from the lily pads.",
    },
    "051": {
        "title": "Branches Across the Stream",
        "character_end": "beaver",
        "location": "babbling_brook",
        "shape": "diamond",
        "maze_style": "walls",
        "story_setup": "Farther downstream, Denny hears splashing and thumping. Birch the beaver is carrying branches near the stream and looks up with a curious smile. Denny follows the winding path to meet Birch for the first time.",
        "instruction": "Find the winding path through the stream maze and meet Birch the beaver!",
        "tts_instruction": "Birch the beaver is building near the stream. Help Denny find the best path through the maze to meet Birch for the first time.",
        "educational_question": "What do beavers build with sticks and mud?",
        "fun_fact": "Beaver dams can slow streams down and create ponds where lots of other animals can live.",
        "completion_message": "Denny found Birch at the water's edge. Birch slapped the stream with his tail in a happy splashy hello when he met Denny for the first time.",
    },
    "052": {
        "title": "Sticks for the Dam",
        "character_end": "beaver",
        "location": "waterfall",
        "shape": "mountain",
        "maze_style": "walls",
        "item_rule": "collect",
        "item_emoji": "🪵",
        "story_setup": "Birch needs sturdy sticks for the new dam. The path near the waterfall is full of bends and little pockets where branches have gathered.",
        "instruction": "Collect all the sticks and bring them to Birch!",
        "tts_instruction": "Branches are waiting along the path. Help Denny collect every stick before reaching Birch the beaver.",
        "educational_question": "Why do beavers build dams in moving water?",
        "fun_fact": "Beavers build dams to make calm ponds where they can build safe homes called lodges.",
        "completion_message": "With every stick collected, Birch's new dam grew stronger. Denny felt like a real forest builder.",
    },
    "053": {
        "title": "Don't Wake the Dog",
        "character_end": "beaver",
        "location": "fox_den",
        "shape": "circle",
        "maze_style": "walls",
        "item_rule": "avoid",
        "item_emoji": "🐶",
        "story_setup": "A sleepy farm dog is napping beside the path near the edge of the woods. Denny must sneak around without waking the dog if he wants to reach Birch.",
        "instruction": "Sneak past the dog and reach Birch safely!",
        "tts_instruction": "The dog is asleep by the path. Help Denny find the safe way around without waking it.",
        "educational_question": "What sounds might wake a sleeping dog or other animal?",
        "fun_fact": "Dogs have very strong noses and sharp hearing. Even while they rest, they notice interesting sounds and smells.",
        "completion_message": "Denny slipped around the sleeping dog without a sound. Birch gave him a proud nod from the stream bank.",
    },
    "054": {
        "title": "Clover in the Clover Patch",
        "character_end": "rabbit",
        "location": "forest_entrance",
        "shape": "circle",
        "maze_style": "walls",
        "story_setup": "Past the stream, Denny spots two long ears popping up from a patch of clover. A little rabbit named Clover is nibbling quietly near the meadow edge. Denny follows the winding path to meet Clover for the first time.",
        "instruction": "Find the path through the clover patch and meet Clover the rabbit!",
        "tts_instruction": "Two long rabbit ears are peeking from the clover patch. Help Denny find the path to meet Clover the rabbit for the first time.",
        "educational_question": "Why do rabbits like to stay near grass, clover, and soft hiding places?",
        "fun_fact": "Rabbits have strong back legs for hopping fast, and their big ears help them hear danger from far away.",
        "completion_message": "Denny reached the clover patch and met Clover at last. Clover twitched a tiny pink nose and gave Denny a bright, friendly hop of hello.",
    },
    "055": {
        "title": "Clover Leaves for Clover",
        "character_end": "rabbit",
        "location": "forest_entrance",
        "shape": "diamond",
        "maze_style": "walls",
        "item_rule": "collect",
        "item_emoji": "🍀",
        "story_setup": "Clover wants to make a soft little lunch from the freshest clover leaves in the meadow. Denny follows the winding path and gathers the best green leaves along the way.",
        "instruction": "Collect all the clover leaves and bring them to Clover!",
        "tts_instruction": "Fresh clover leaves are scattered through the meadow. Help Denny collect every clover leaf before reaching Clover.",
        "educational_question": "What kinds of plants do rabbits like to nibble?",
        "fun_fact": "Wild rabbits like to eat grasses, clover, leaves, and tender plants they can find close to the ground.",
        "completion_message": "Every clover leaf made Clover's lunch pile bigger. Clover gave Denny a happy hop and shared the shadiest spot in the meadow.",
    },
    "056": {
        "title": "Sneak Past the Thorn Bushes",
        "character_end": "rabbit",
        "location": "berry_bush",
        "shape": "triangle",
        "maze_style": "walls",
        "item_rule": "avoid",
        "item_emoji": "🌵",
        "story_setup": "The safest shortcut to Clover's burrow passes near some prickly thorn bushes. Denny has to move carefully so he does not brush against any sharp thorns on the way.",
        "instruction": "Avoid the thorn bushes and reach Clover safely!",
        "tts_instruction": "Prickly thorn bushes are crowding the path. Help Denny find a careful way around them to reach Clover.",
        "educational_question": "Why do some bushes and plants grow sharp thorns?",
        "fun_fact": "Thorns can protect plants by making hungry animals think twice before nibbling too much.",
        "completion_message": "Denny slipped past every thorn bush without a scratch. Clover smiled and thumped one happy foot outside the burrow.",
    },
    "057": {
        "title": "Lights in the Meadow",
        "character_end": "firefly",
        "location": "firefly_meadow",
        "shape": "rect",
        "maze_style": "walls",
        "story_setup": "As evening falls, tiny golden lights blink in the meadow. One warm little light floats closer and turns out to be Glow the firefly. Denny follows the dusky path to meet Glow for the first time.",
        "instruction": "Find the path through the dusky meadow and meet Glow the firefly!",
        "tts_instruction": "Golden lights are blinking in the meadow. Help Denny find the winding path to meet Glow the firefly for the first time.",
        "educational_question": "Why do some insects glow in the dark?",
        "fun_fact": "Fireflies glow to talk to one another. Each kind of firefly has its own special blinking pattern.",
        "completion_message": "Denny reached Glow just as the meadow lit up like a tiny starry sky. It was the first time they met, and Maya gasped because the whole meadow looked so beautiful.",
    },
    "058": {
        "title": "Golden Lights to Gather",
        "character_end": "firefly",
        "location": "firefly_meadow",
        "shape": "diamond",
        "maze_style": "walls",
        "item_rule": "collect",
        "item_emoji": "✨",
        "story_setup": "Glow asks Denny to gather twinkling light-specks scattered along the meadow path so the night trail will shine even brighter.",
        "instruction": "Collect all the glowing lights and bring them to Glow!",
        "tts_instruction": "Twinkling lights are floating all along the trail. Help Denny collect every glowing spark before reaching Glow.",
        "educational_question": "What other things in nature glow or sparkle at night?",
        "fun_fact": "Moonlight, fireflies, and even some mushrooms can make a forest glow at night in magical ways.",
        "completion_message": "Every golden sparkle made the meadow brighter. Glow whirled around Denny in a happy ring of light.",
    },
    "059": {
        "title": "Avoid the Spider Webs",
        "character_end": "firefly",
        "location": "forest_canopy",
        "shape": "triangle",
        "maze_style": "walls",
        "item_rule": "avoid",
        "item_emoji": "🕸️",
        "story_setup": "High under the branches, silver spider webs stretch across the night path. Denny must follow Glow's light without getting caught in any webs.",
        "instruction": "Avoid the spider webs and follow Glow's path!",
        "tts_instruction": "Shiny spider webs are stretched across the branches. Help Denny avoid them and keep following Glow.",
        "educational_question": "Why do spiders build webs?",
        "fun_fact": "Spider silk is very strong for something so thin. Some webs are sticky so insects get caught inside.",
        "completion_message": "Denny zigzagged past every web. Glow blinked proudly and led him onward to the last surprise of the night.",
    },
    "060": {
        "title": "The Leaf Lantern Path",
        "character_end": "firefly",
        "location": "forest_canopy",
        "shape": "leaf",
        "maze_style": "leaf",
        "item_rule": "collect",
        "item_emoji": "🍂",
        "story_setup": "Glow reveals a final secret path shaped like a giant leaf drifting through the night forest. Denny follows the curvy leaf trail and collects autumn leaves that shine in the moonlight.",
        "instruction": "Follow the leaf path and collect all the leaves to reach Glow!",
        "tts_instruction": "A giant leaf path is glowing in the moonlight. Help Denny collect every autumn leaf and follow the curvy trail to Glow.",
        "educational_question": "Why do many leaves change color before they fall?",
        "fun_fact": "Leaves look green in summer because of chlorophyll. In autumn, the green fades and yellow, orange, and red colors can show.",
        "completion_message": "Denny gathered every glowing leaf and reached Glow at the tip of the giant leaf path. The whole forest shimmered softly around them.",
    },
}

FOREST_STORY_POSITIONS = {
    "041": {"start": "bottom_left", "end": "top_right"},
    "042": {"start": "bottom_right", "end": "top_left"},
    "043": {"start": "bottom_left", "end": "top_right"},
    "044": {"start": "bottom_left", "end": "top_right"},
    "045": {"start": "bottom_left", "end": "top_right"},
    "046": {"start": "bottom_left", "end": "top_right"},
    "047": {"start": "bottom_left", "end": "top_right"},
    "048": {"start": "bottom_right", "end": "top_left"},
    "049": {"start": "bottom_left", "end": "top_right"},
    "050": {"start": "bottom_left", "end": "top_right"},
    "051": {"start": "bottom_left", "end": "top_right"},
    "052": {"start": "bottom_right", "end": "top_left"},
    "053": {"start": "bottom_left", "end": "top_right"},
    "054": {"start": "bottom_left", "end": "top_right"},
    "055": {"start": "bottom_left", "end": "top_right"},
    "056": {"start": "bottom_right", "end": "top_left"},
    "057": {"start": "bottom_left", "end": "top_right"},
    "058": {"start": "bottom_left", "end": "top_right"},
    "059": {"start": "bottom_left", "end": "top_right"},
    "060": {"start": "bottom_left", "end": "top_right"},
}


def points_to_segments(points: list[tuple[float, float]]) -> list[dict]:
    segments = []
    for index in range(len(points) - 1):
        start = points[index]
        end = points[index + 1]
        segments.append({
            "start": {"x": round(start[0], 1), "y": round(start[1], 1)},
            "end": {"x": round(end[0], 1), "y": round(end[1], 1)},
        })
    return segments


def place_items_on_points(points: list[tuple[float, float]], count: int, emoji: str) -> list[dict]:
    if count <= 0 or len(points) < 3:
        return []
    stride = max(1, len(points) // (count + 1))
    items = []
    for idx in range(1, count + 1):
        point = points[min(idx * stride, len(points) - 2)]
        items.append({
            "x": round(point[0], 1),
            "y": round(point[1], 1),
            "emoji": emoji,
            "on_solution": True,
        })
    return items


def points_to_svg(points: list[tuple[float, float]]) -> str:
    svg_path = f"M {points[0][0]:.1f} {points[0][1]:.1f}"
    for index in range(1, len(points) - 1):
        cx = points[index][0]
        cy = points[index][1]
        nx = (points[index][0] + points[index + 1][0]) / 2
        ny = (points[index][1] + points[index + 1][1]) / 2
        svg_path += f" Q {cx:.1f} {cy:.1f} {nx:.1f} {ny:.1f}"
    svg_path += f" L {points[-1][0]:.1f} {points[-1][1]:.1f}"
    return svg_path


def generate_organic(diff_name: str, canvas_width: int, canvas_height: int, item_emoji: str = "🌸") -> dict:
    num_petals = ORGANIC_PETALS[diff_name]
    gen = OrganicPathGenerator(width=canvas_width, height=canvas_height, path_width=35)
    data = gen.generate(style="flower", num_petals=num_petals, item_emoji=item_emoji)
    return {
        "svg_path": data["svg_path"],
        "solution_path": "",
        "width": data["path_width"],
        "complexity": diff_name,
        "maze_type": "organic",
        "start_point": data["start_point"],
        "end_point": data["end_point"],
        "segments": data["segments"],
        "canvas_width": data["canvas_width"],
        "canvas_height": data["canvas_height"],
        "control_points": data.get("control_points", []),
        "items": data.get("items", []),
    }


def generate_leaf_path(diff_name: str, item_emoji: str) -> dict:
    mid_x = 300.0

    templates = {
        "easy": [
            (300.0, 452.0),
            (300.0, 412.0),
            (282.0, 384.0),
            (230.0, 352.0),
            (162.0, 334.0),
            (214.0, 312.0),
            (248.0, 296.0),
            (202.0, 256.0),
            (124.0, 220.0),
            (210.0, 204.0),
            (252.0, 182.0),
            (226.0, 140.0),
            (172.0, 112.0),
            (242.0, 108.0),
            (286.0, 110.0),
            (300.0, 72.0),
            (314.0, 110.0),
            (356.0, 108.0),
            (430.0, 118.0),
            (370.0, 146.0),
            (344.0, 184.0),
            (392.0, 208.0),
            (476.0, 234.0),
            (386.0, 264.0),
            (346.0, 296.0),
            (396.0, 320.0),
            (450.0, 346.0),
            (380.0, 362.0),
            (324.0, 394.0),
            (312.0, 408.0),
            (304.0, 240.0),
            (300.0, 42.0),
        ],
        "medium": [
            (300.0, 452.0),
            (300.0, 420.0),
            (290.0, 394.0),
            (262.0, 374.0),
            (226.0, 356.0),
            (174.0, 338.0),
            (140.0, 330.0),
            (184.0, 316.0),
            (226.0, 302.0),
            (252.0, 288.0),
            (222.0, 268.0),
            (182.0, 246.0),
            (128.0, 222.0),
            (182.0, 210.0),
            (228.0, 196.0),
            (256.0, 176.0),
            (236.0, 154.0),
            (208.0, 132.0),
            (168.0, 112.0),
            (222.0, 106.0),
            (270.0, 102.0),
            (286.0, 84.0),
            (300.0, 52.0),
            (314.0, 84.0),
            (332.0, 102.0),
            (380.0, 106.0),
            (438.0, 116.0),
            (394.0, 136.0),
            (364.0, 156.0),
            (344.0, 178.0),
            (374.0, 196.0),
            (420.0, 212.0),
            (474.0, 232.0),
            (420.0, 248.0),
            (380.0, 266.0),
            (348.0, 286.0),
            (378.0, 302.0),
            (422.0, 322.0),
            (462.0, 344.0),
            (412.0, 352.0),
            (366.0, 366.0),
            (330.0, 388.0),
            (314.0, 404.0),
            (304.0, 234.0),
            (300.0, 42.0),
        ],
        "hard": [
            (300.0, 452.0),
            (300.0, 424.0),
            (294.0, 404.0),
            (278.0, 390.0),
            (254.0, 376.0),
            (226.0, 362.0),
            (188.0, 348.0),
            (148.0, 336.0),
            (128.0, 328.0),
            (162.0, 320.0),
            (194.0, 312.0),
            (224.0, 302.0),
            (248.0, 290.0),
            (228.0, 278.0),
            (198.0, 262.0),
            (164.0, 246.0),
            (124.0, 226.0),
            (166.0, 216.0),
            (204.0, 206.0),
            (234.0, 194.0),
            (256.0, 178.0),
            (240.0, 164.0),
            (216.0, 146.0),
            (192.0, 128.0),
            (164.0, 112.0),
            (204.0, 106.0),
            (240.0, 102.0),
            (270.0, 98.0),
            (286.0, 82.0),
            (300.0, 44.0),
            (314.0, 82.0),
            (332.0, 98.0),
            (360.0, 102.0),
            (394.0, 108.0),
            (438.0, 120.0),
            (406.0, 134.0),
            (380.0, 146.0),
            (360.0, 162.0),
            (344.0, 178.0),
            (366.0, 192.0),
            (398.0, 206.0),
            (438.0, 220.0),
            (476.0, 236.0),
            (432.0, 248.0),
            (398.0, 260.0),
            (372.0, 274.0),
            (348.0, 288.0),
            (370.0, 300.0),
            (402.0, 314.0),
            (436.0, 328.0),
            (468.0, 344.0),
            (428.0, 352.0),
            (392.0, 360.0),
            (362.0, 372.0),
            (336.0, 388.0),
            (318.0, 404.0),
            (308.0, 250.0),
            (302.0, 120.0),
            (300.0, 42.0),
        ],
    }

    points = templates[diff_name]
    item_points = {
        "easy": [
            (162.0, 334.0),
            (124.0, 220.0),
            (172.0, 112.0),
            (300.0, 72.0),
            (430.0, 118.0),
            (476.0, 234.0),
            (450.0, 346.0),
        ],
        "medium": [
            (140.0, 330.0),
            (128.0, 222.0),
            (168.0, 112.0),
            (300.0, 52.0),
            (438.0, 116.0),
            (474.0, 232.0),
            (462.0, 344.0),
        ],
        "hard": [
            (128.0, 328.0),
            (124.0, 226.0),
            (164.0, 112.0),
            (300.0, 44.0),
            (438.0, 120.0),
            (476.0, 236.0),
            (468.0, 344.0),
        ],
    }[diff_name]

    item_count = min(LEAF_ITEM_COUNTS[diff_name], len(item_points))
    items = [
        {
            "x": round(point[0], 1),
            "y": round(point[1], 1),
            "emoji": item_emoji,
            "on_solution": True,
        }
        for point in item_points[:item_count]
    ]
    return {
        "svg_path": points_to_svg(points),
        "solution_path": "",
        "width": LEAF_WIDTHS[diff_name],
        "complexity": diff_name,
        "maze_type": "organic",
        "start_point": {"x": round(points[0][0], 1), "y": round(points[0][1], 1)},
        "end_point": {"x": round(points[-1][0], 1), "y": round(points[-1][1], 1)},
        "segments": points_to_segments(points),
        "canvas_width": 600,
        "canvas_height": 500,
        "control_points": [
            {"x": round(point[0], 1), "y": round(point[1], 1)}
            for point in points
        ],
        "items": items,
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
                random.seed(f"forest-{story_num_str}-{diff_name}")

                if maze_style == "organic":
                    maze_data = generate_organic(
                        diff_name,
                        canvas_width=600,
                        canvas_height=500,
                        item_emoji=item_emoji or "🌸",
                    )
                elif maze_style == "leaf":
                    maze_data = generate_leaf_path(diff_name, item_emoji or "🍂")
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
                    if raw.get("avoid_items"):
                        maze_data["avoid_items"] = raw["avoid_items"]

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
                    "path_data": maze_data,
                    "visual_theme": {
                        "background_color": location["background_color"],
                        "decorative_elements": location["decorative_elements"],
                    },
                    "audio_instruction": f"denny_{story_num_str}_instruction.mp3",
                    "audio_completion": f"denny_{story_num_str}_completion.mp3",
                }
                if item_rule:
                    variant["item_rule"] = item_rule
                    variant["item_emoji"] = item_emoji

                all_labs.append(variant)
            except Exception as exc:
                print(f"  Error generating {variant_id}: {exc}")
                import traceback
                traceback.print_exc()
                continue

    for lab in all_labs:
        json_path = output_dir / f"{lab['id']}.json"
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(lab, f, indent=2, ensure_ascii=False)
        print(f"  Saved: {json_path.name}")

    manifest_path = output_dir / "manifest.json"
    manifest = {"universe": "denny", "total": 0, "packs": [], "labyrinths": []}
    if manifest_path.exists():
        with open(manifest_path, encoding="utf-8") as f:
            manifest = json.load(f)

    story_ids = set(stories.keys())
    existing_labs = [
        entry for entry in manifest.get("labyrinths", [])
        if not any(f"denny_{story_id}_" in entry["id"] for story_id in story_ids)
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

    packs = [pack for pack in manifest.get("packs", []) if pack.get("id") != "forest_adventures"]
    packs.append({
        "id": "forest_adventures",
        "title": "Denny in the Forest",
        "free_stories": 0,
        "stories": sorted({int(story_id) for story_id in FOREST_STORIES.keys()}),
    })
    manifest["packs"] = packs

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"\nManifest: {manifest_path} ({manifest['total']} entries)")
    print(f"Generated: {len(all_labs)} variants")


def main():
    parser = argparse.ArgumentParser(description="Generate 'Denny in the Forest' pack")
    parser.add_argument("--output", type=str, default=None)
    parser.add_argument(
        "--test",
        action="store_true",
        help="Generate stories 041-044 at medium difficulty only",
    )
    args = parser.parse_args()

    output_dir = (
        Path(args.output) if args.output
        else Path(__file__).parent / "output" / "labyrinths"
    )

    if args.test:
        stories = {key: FOREST_STORIES[key] for key in ["041", "042", "043", "044"]}
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
