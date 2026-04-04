"""Generate 'Denny in Space' pack — stories 021-030 at 3 difficulty levels (30 files total).

Usage:
    python generate_space_pack.py --output path/to/labyrinths
    python generate_space_pack.py  # defaults to output/labyrinths/

After running, copy the generated JSON files to:
    LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/
and update the app bundle in Xcode.
"""

import argparse
import json
import sys
from pathlib import Path

import yaml

# Allow importing from the same directory
sys.path.insert(0, str(Path(__file__).parent))

from maze_generator import FullMazeGenerator


def load_config() -> dict:
    config_path = Path(__file__).parent / "config.yaml"
    with open(config_path) as f:
        return yaml.safe_load(f)


# Grid scale factors for shaped mazes — copied from generator.py
SHAPE_GRID_SCALE = {
    "rect": 1.0,
    "mountain": 1.25,
    "tree": 1.3,
    "triangle": 1.5,
    "diamond": 1.5,
    "circle": 1.8,
    "moon": 1.8,
    "rocket": 2.0,
}


# ---------------------------------------------------------------------------
# Universe
# ---------------------------------------------------------------------------

def load_space_universe() -> dict:
    universe_path = Path(__file__).parent / "characters" / "denny_space_universe.json"
    with open(universe_path) as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Story data
# ---------------------------------------------------------------------------

SPACE_STORIES = {
    "021": {
        "title": "Denny's First Launch",
        "character_end": "mama_coral",
        "location": "rocket_launch_pad",
        "item_rule": "collect",
        "item_emoji": "⭐",
        "shape": "rect",
        "story_setup": "Denny is blasting off into space for the very first time! Mommy Coral is waiting at the launch pad control room. Collect all the guiding stars on the way!",
        "instruction": "Collect all the stars and reach Mommy Coral at the control room!",
        "tts_instruction": "Blast off! Help Denny collect every guiding star on the launch pad before reaching Mommy Coral at the control room.",
        "educational_question": "How fast does a rocket need to go to leave Earth? Do you know?",
        "fun_fact": "A rocket needs to travel at 40,000 kilometers per hour to escape Earth's gravity. That's fast enough to go around the world in less than an hour!",
        "completion_message": "Denny launched into space! Mommy Coral is so proud!",
    },
    "022": {
        "title": "Denny Walks on the Moon",
        "character_end": "daddy_reef",
        "location": "moon_crater",
        "item_rule": "collect",
        "item_emoji": "🪨",
        "shape": "mountain",
        "story_setup": "Denny is bouncing across the Moon's surface! Daddy Reef is waiting near the biggest crater. Collect all the moon rocks along the way!",
        "instruction": "Collect all the moon rocks and bounce your way to Daddy Reef!",
        "tts_instruction": "Bounce on the Moon! Help Denny pick up every moon rock in the crater before finding Daddy Reef.",
        "educational_question": "Why do things feel lighter on the Moon than on Earth?",
        "fun_fact": "The Moon has only one-sixth of Earth's gravity! If you weigh 30 kilograms on Earth, you'd weigh just 5 kilograms on the Moon.",
        "completion_message": "Denny collected all the moon rocks! Daddy Reef is amazed by the bouncy adventure!",
    },
    "023": {
        "title": "Denny's Asteroid Adventure",
        "character_end": "sandy",
        "location": "asteroid_belt",
        "item_rule": "collect",
        "item_emoji": "💎",
        "shape": "triangle",
        "story_setup": "Sandy is hiding in the asteroid belt playing space tag! Denny must dodge the floating rocks and collect all the space gems while searching for her.",
        "instruction": "Collect all the space gems and find Sandy in the asteroid belt!",
        "tts_instruction": "Asteroid adventure! Help Denny collect every sparkling gem floating in the asteroid belt before finding Sandy.",
        "educational_question": "What is an asteroid made of? Is it the same as a planet?",
        "fun_fact": "Asteroids are space rocks left over from when our solar system formed 4.6 billion years ago! The asteroid belt between Mars and Jupiter has millions of them.",
        "completion_message": "Denny found Sandy and collected all the gems! What a rocky adventure!",
    },
    "024": {
        "title": "Denny Meets Aliens",
        "character_end": "finn",
        "location": "alien_planet",
        "item_rule": "collect",
        "item_emoji": "🌸",
        "shape": "tree",
        "story_setup": "Denny has landed on a colorful alien planet! Finn is waiting by the strange glowing forest. Collect the alien flowers as a gift for the planet's inhabitants!",
        "instruction": "Collect all the alien flowers and find Finn in the glowing forest!",
        "tts_instruction": "Alien planet! Help Denny gather every colorful alien flower in the glowing forest before reaching Finn.",
        "educational_question": "Do you think there could be life on other planets? What might it look like?",
        "fun_fact": "Scientists have discovered over 5,000 planets outside our solar system! Some are in the 'habitable zone' where liquid water might exist.",
        "completion_message": "Denny delivered the flowers to the aliens! Finn says they loved them!",
    },
    "025": {
        "title": "Denny at the Space Station",
        "character_end": "stella",
        "location": "space_station",
        "item_rule": "collect",
        "item_emoji": "🔧",
        "shape": "diamond",
        "story_setup": "Stella needs help fixing the space station! Tools are floating all over in zero gravity. Denny must collect them before they drift away into space.",
        "instruction": "Collect all the floating tools and help Stella fix the station!",
        "tts_instruction": "Zero gravity emergency! Help Denny collect every floating tool before finding Stella to fix the space station.",
        "educational_question": "What does zero gravity feel like? What do astronauts do differently in space?",
        "fun_fact": "On the International Space Station, astronauts sleep in sleeping bags attached to the wall and eat food from pouches — otherwise it floats away!",
        "completion_message": "Denny collected all the tools! Stella fixed the space station just in time!",
    },
    "026": {
        "title": "Denny in the Nebula",
        "character_end": "ollie",
        "location": "nebula_cloud",
        "item_rule": "collect",
        "item_emoji": "✨",
        "shape": "circle",
        "story_setup": "Ollie is painting the nebula with glowing stardust! Denny is drifting through the colorful clouds collecting the brightest sparks to help Ollie create a masterpiece.",
        "instruction": "Collect all the stardust sparks and find Ollie in the nebula!",
        "tts_instruction": "Drifting through the nebula! Help Denny collect every glowing spark in the colorful clouds before finding Ollie.",
        "educational_question": "What is a nebula? How are stars born?",
        "fun_fact": "A nebula is a giant cloud of gas and dust in space where new stars are born! The Eagle Nebula has a famous region called 'Pillars of Creation' where stars are forming right now.",
        "completion_message": "Denny collected all the stardust! Ollie's nebula painting is beautiful!",
    },
    "027": {
        "title": "Denny Rides a Comet",
        "character_end": "shelly",
        "location": "comet_tail",
        "item_rule": "collect",
        "item_emoji": "🧊",
        "shape": "rect",
        "story_setup": "Shelly is telling stories from the tail of a speeding comet! Denny is racing to reach Shelly while collecting chunks of glowing space ice along the way.",
        "instruction": "Collect all the ice chunks and race to Shelly at the comet's tip!",
        "tts_instruction": "Zooming on a comet! Help Denny pick up every glowing ice chunk in the comet's tail before reaching Shelly.",
        "educational_question": "What is a comet made of? Why does it have a glowing tail?",
        "fun_fact": "Comets are giant balls of ice and rock! As they get close to the Sun, the ice melts and creates a glowing tail that can stretch millions of kilometers.",
        "completion_message": "Denny caught the comet and reached Shelly! What a wild space ride!",
    },
    "028": {
        "title": "Denny at the Black Hole",
        "character_end": "bubbles",
        "location": "black_hole_edge",
        "item_rule": "collect",
        "item_emoji": "💫",
        "shape": "circle",
        "story_setup": "Bubbles is studying the swirling light near a black hole! Denny must carefully collect the glowing light rings while avoiding getting too close to the center.",
        "instruction": "Collect all the light rings and find Bubbles near the black hole's edge!",
        "tts_instruction": "Careful near the black hole! Help Denny collect every glowing light ring swirling around the edge before finding Bubbles.",
        "educational_question": "What is a black hole? Can anything escape it?",
        "fun_fact": "A black hole has such powerful gravity that even light cannot escape! They form when a massive star collapses at the end of its life.",
        "completion_message": "Denny collected all the light rings! Bubbles says the data is priceless — amazing science!",
    },
    "029": {
        "title": "Denny and Saturn's Rings",
        "character_end": "pearl",
        "location": "saturn_rings",
        "item_rule": "collect",
        "item_emoji": "🪐",
        "shape": "mountain",
        "story_setup": "Pearl is drifting through Saturn's spectacular rings! Denny is surfing the ring particles collecting the shiniest ice chunks to bring back as souvenirs.",
        "instruction": "Collect all the shiny ice rings and float your way to Pearl!",
        "tts_instruction": "Surfing Saturn's rings! Help Denny collect every shiny ice chunk in the rings before finding Pearl floating nearby.",
        "educational_question": "What are Saturn's rings made of? How many rings does it have?",
        "fun_fact": "Saturn's rings are made mostly of ice and rock, ranging from tiny grains to chunks as big as a house! The rings are incredibly thin — only about 10 meters thick in places.",
        "completion_message": "Denny surfed all the way to Pearl through Saturn's rings! The most beautiful sight in the solar system!",
    },
    "030": {
        "title": "Denny's Starfield Journey",
        "character_end": "finn",
        "location": "starfield",
        "item_rule": "collect",
        "item_emoji": "🌟",
        "shape": "diamond",
        "story_setup": "Finn has mapped out a constellation just for Denny! Deep in the open starfield, Denny must connect the glowing stars by collecting them in order to reveal the surprise picture.",
        "instruction": "Collect all the constellation stars and reach Finn at the center of space!",
        "tts_instruction": "Stars everywhere! Help Denny collect every glowing constellation star in the starfield before meeting Finn at the center.",
        "educational_question": "What is a constellation? Can you name one?",
        "fun_fact": "There are 88 officially named constellations! Ancient people used them as a map to navigate at sea and to track the seasons. Orion is one of the most famous.",
        "completion_message": "Denny connected all the stars! Finn's constellation spells out D-E-N-N-Y!",
    },
    # Stories 031-040 are regular (no item collection)
    "031": {
        "title": "Denny Lands on Mars",
        "character_end": "mama_coral",
        "location": "mars_surface",
        "shape": "circle",
        "story_setup": "Denny's rocket has landed on the red planet! Mommy Coral is waiting at the base camp across the dusty Martian plains.",
        "instruction": "Navigate the Martian surface and reach Mommy Coral at base camp!",
        "tts_instruction": "Welcome to Mars! Help Denny navigate the dusty red paths to reach Mommy Coral at the base camp.",
        "educational_question": "Why is Mars called the Red Planet? What makes it red?",
        "fun_fact": "Mars looks red because its soil is full of iron oxide — that's rust! Mars also has the tallest volcano in the solar system, Olympus Mons, three times taller than Mount Everest.",
        "completion_message": "Denny explored Mars and found Mommy Coral! The first crab on Mars!",
    },
    "032": {
        "title": "Denny Inside Jupiter's Storm",
        "character_end": "daddy_reef",
        "location": "jupiter_storm",
        "shape": "diamond",
        "story_setup": "Daddy Reef is studying Jupiter's enormous swirling storm! Denny's rocket must weave carefully through the giant swirling cloud bands to reach him.",
        "instruction": "Navigate through Jupiter's storm clouds and reach Daddy Reef!",
        "tts_instruction": "Into the storm! Help Denny navigate through Jupiter's swirling cloud bands to find Daddy Reef in the eye of the storm.",
        "educational_question": "How big is Jupiter's Great Red Spot? Is it bigger than Earth?",
        "fun_fact": "Jupiter's Great Red Spot is a storm that has been raging for over 350 years! It's so big that Earth could fit inside it. Jupiter is also the largest planet — 1,300 Earths could fit inside!",
        "completion_message": "Denny flew through the storm! Daddy Reef has all the data they need!",
    },
    "033": {
        "title": "Denny Builds the Lunar Base",
        "character_end": "stella",
        "location": "lunar_base",
        "shape": "mountain",
        "story_setup": "Stella is building a cozy base on the Moon! Denny must bounce across the winding lunar surface paths to help her.",
        "instruction": "Bounce across the Moon and reach Stella at the lunar base!",
        "tts_instruction": "Base building time! Help Denny bounce across the winding Moon paths to reach Stella at the lunar base.",
        "educational_question": "Could people really live on the Moon one day? What would they need?",
        "fun_fact": "Scientists are working on plans for a real Moon base! People living there would need air, water, food, and protection from the Sun's radiation. They might even grow plants underground!",
        "completion_message": "Denny arrived! Together, they finish building the lunar base!",
    },
    "034": {
        "title": "Denny and the Wormhole",
        "character_end": "ollie",
        "location": "wormhole",
        "shape": "circle",
        "story_setup": "Ollie has discovered a glowing wormhole that leads to another galaxy! Denny must navigate the swirling energy currents to reach the portal entrance.",
        "instruction": "Navigate the swirling energy and find Ollie at the wormhole!",
        "tts_instruction": "Amazing discovery! Help Denny follow the swirling energy paths to reach Ollie at the wormhole entrance.",
        "educational_question": "What is a wormhole? Could we use one to travel to other galaxies?",
        "fun_fact": "A wormhole is a theoretical tunnel through space and time! Scientists think they might exist but have never found one. If they do exist, they could allow instant travel between distant parts of the universe.",
        "completion_message": "Denny reached the portal! Denny and Ollie jump through the wormhole together!",
    },
    "035": {
        "title": "Denny in the Alien Jungle",
        "character_end": "shelly",
        "location": "alien_jungle",
        "shape": "tree",
        "story_setup": "Shelly is painting the bioluminescent alien jungle! Denny must wind through the glowing plants and strange alien paths to reach her.",
        "instruction": "Wind through the alien jungle and find Shelly!",
        "tts_instruction": "Glowing jungle! Help Denny find a path through the bioluminescent alien plants to reach Shelly.",
        "educational_question": "What does bioluminescent mean? Can you think of animals on Earth that glow?",
        "fun_fact": "Bioluminescence means making your own light! Fireflies, some jellyfish, anglerfish, and deep-sea creatures all glow. Some scientists think alien life might glow too!",
        "completion_message": "Denny found Shelly! The alien jungle is the most beautiful place in the universe!",
    },
    "036": {
        "title": "Denny on the Ice Planet",
        "character_end": "bubbles",
        "location": "ice_planet",
        "shape": "diamond",
        "story_setup": "Bubbles found the most beautiful ice crystal planet! The paths between the frozen crystal formations are tricky — Denny must navigate carefully to reach Bubbles.",
        "instruction": "Navigate the icy crystal paths and reach Bubbles at the frozen sea!",
        "tts_instruction": "Icy adventure! Help Denny navigate the slippery ice crystal paths across the frozen planet to reach Bubbles.",
        "educational_question": "Which planet in our solar system is the coldest? How cold does it get?",
        "fun_fact": "Neptune is the coldest planet at -214°C! But Europa, one of Jupiter's moons, has a frozen ocean with liquid water underneath — and scientists think it might have life!",
        "completion_message": "Denny reached Bubbles! They slide together across the frozen sea!",
    },
    "037": {
        "title": "Denny's Space Race",
        "character_end": "sandy",
        "location": "space_race",
        "shape": "rect",
        "story_setup": "Sandy has set up a galactic racing course and is waiting at the finish line! Denny's rocket must follow the winding track to reach the big finish.",
        "instruction": "Follow the racing track and zoom to Sandy at the finish line!",
        "tts_instruction": "Race time! Help Denny rocket along the galactic race course to reach Sandy at the finish line!",
        "educational_question": "How fast do real rockets travel? Can you imagine going that fast?",
        "fun_fact": "The fastest spacecraft ever launched, the Parker Solar Probe, travels at 692,000 kilometers per hour — that's fast enough to fly from New York to Los Angeles in less than 15 seconds!",
        "completion_message": "Denny wins the space race! Sandy gives the winner's trophy — a shiny star!",
    },
    "038": {
        "title": "Denny Visits the Robot Planet",
        "character_end": "pearl",
        "location": "robot_planet",
        "shape": "mountain",
        "story_setup": "Pearl has befriended the robots on their mechanical planet! The robot city has many winding paths — Denny must find Pearl among the gear towers and conveyor belts.",
        "instruction": "Navigate the mechanical city and find Pearl on the Robot Planet!",
        "tts_instruction": "Mechanical world! Help Denny navigate the winding robot city paths to find Pearl.",
        "educational_question": "What can robots do that humans can't? Can you name a robot you know about?",
        "fun_fact": "There are robots on Mars right now! The Perseverance rover explores the Martian surface taking photos and collecting rock samples. It even has a tiny helicopter friend called Ingenuity!",
        "completion_message": "Denny found Pearl! The friendly robots put on a light show to celebrate!",
    },
    "039": {
        "title": "Denny at the Galaxy Center",
        "character_end": "finn",
        "location": "galaxy_center",
        "shape": "circle",
        "story_setup": "Finn has discovered a mysterious signal from the center of the Milky Way galaxy! Denny must navigate through dense clouds of glowing stars to find him.",
        "instruction": "Navigate the dense starfields and reach Finn at the galaxy core!",
        "tts_instruction": "Deep space mission! Help Denny navigate through the dense glowing star clouds to reach Finn at the galaxy core.",
        "educational_question": "What is in the center of our galaxy? Have you heard of a supermassive black hole?",
        "fun_fact": "At the center of our Milky Way galaxy sits a supermassive black hole called Sagittarius A*. It's four million times heavier than our Sun! Thankfully, we're safely 26,000 light years away from it.",
        "completion_message": "Denny reached the galaxy core! Together, they decode the mysterious signal!",
    },
    "040": {
        "title": "Denny Returns Home",
        "character_end": "mama_coral",
        "location": "earth_orbit",
        "shape": "rect",
        "story_setup": "After all the space adventures, Denny is finally heading home! Mommy Coral is waiting with a big hug. Denny must navigate through Earth's orbit to reach her.",
        "instruction": "Navigate through Earth's orbit and fly home to Mommy Coral!",
        "tts_instruction": "Heading home! Help Denny navigate through Earth's beautiful orbit to land safely and reach Mommy Coral.",
        "educational_question": "If you could visit any planet or place in space, where would you go?",
        "fun_fact": "The International Space Station orbits Earth 16 times every day! Astronauts who return from long missions have to learn to walk again because their muscles got weak in zero gravity.",
        "completion_message": "Denny is home! Mommy Coral hugs Denny tight — the greatest space explorer in the world!",
    },
}

SPACE_STORY_POSITIONS = {
    "021": {"start": "bottom_left",  "end": "top_right"},
    "022": {"start": "bottom_right", "end": "top_left"},
    "023": {"start": "bottom_left",  "end": "top_right"},
    "024": {"start": "bottom_right", "end": "top_left"},
    "025": {"start": "bottom_left",  "end": "top_right"},
    "026": {"start": "bottom_right", "end": "top_left"},
    "027": {"start": "bottom_left",  "end": "top_right"},
    "028": {"start": "bottom_right", "end": "top_left"},
    "029": {"start": "bottom_left",  "end": "top_right"},
    "030": {"start": "bottom_right", "end": "top_left"},
    "031": {"start": "bottom",       "end": "top"},
    "032": {"start": "bottom_right", "end": "top_left"},
    "033": {"start": "bottom",       "end": "top"},
    "034": {"start": "bottom_right", "end": "top_left"},
    "035": {"start": "bottom_left",  "end": "top_right"},
    "036": {"start": "bottom_right", "end": "top_left"},
    "037": {"start": "bottom_left",  "end": "top_right"},
    "038": {"start": "bottom_right", "end": "top_left"},
    "039": {"start": "bottom_left",  "end": "top_right"},
    "040": {"start": "bottom_right", "end": "top_left"},
}

SPACE_ITEM_COUNTS = {
    "easy": 2, "medium": 4, "hard": 6,
}


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

def generate_space_variants(output_dir: Path):
    """Generate 30 space labyrinth variants (10 stories x 3 difficulty levels)."""
    config = load_config()
    difficulty_levels = config["difficulty_levels"]
    universe = load_space_universe()
    maze_gen = FullMazeGenerator()

    output_dir.mkdir(parents=True, exist_ok=True)
    all_labs = []
    difficulty_names = ["easy", "medium", "hard"]

    for story_num_str, story in SPACE_STORIES.items():
        end_char_key = story["character_end"]
        end_char = universe["characters"][end_char_key]
        denny = universe["characters"]["denny"]
        location = universe["locations"][story["location"]]
        item_rule = story.get("item_rule")
        item_emoji = story.get("item_emoji")
        shape = story["shape"]
        positions = SPACE_STORY_POSITIONS.get(story_num_str, {})
        start_pos = positions.get("start")
        end_pos = positions.get("end")

        for diff_name in difficulty_names:
            variant_id = f"denny_{story_num_str}_{diff_name}"
            diff_config = difficulty_levels[diff_name]
            base_rows, base_cols = diff_config["grid_size"]
            path_width = diff_config["path_width"]
            item_count = SPACE_ITEM_COUNTS[diff_name] if item_rule else 0

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
                    start_position=start_pos,
                    end_position=end_pos,
                )
                if item_rule:
                    maze_kwargs["item_rule"] = item_rule
                    maze_kwargs["item_count"] = item_count
                    maze_kwargs["item_emoji"] = item_emoji
                maze_data = maze_gen.generate_maze(**maze_kwargs)

                # Collect stories get a dark starfield background
                bg_color = "#050510" if item_rule == "collect" else location["background_color"]
                decorative = location["decorative_elements"]

                variant = {
                    "id": variant_id,
                    "age_range": "3-6",
                    "difficulty": diff_name,
                    "theme": "space",
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
                        "image_asset": "denny_space",
                    },
                    "character_end": {
                        "type": end_char["type"],
                        "description": end_char["description"],
                        "position": "top_right",
                        "name": end_char["name"],
                        "image_asset": f"{end_char_key}_space",
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
        print(f"  Saved: {json_path}")

    # Append space entries to manifest (merge with existing)
    manifest_path = output_dir / "manifest.json"
    manifest = {"universe": "denny", "total": 0, "packs": [], "labyrinths": []}
    if manifest_path.exists():
        with open(manifest_path) as f:
            manifest = json.load(f)

    # Remove old space entries before re-appending
    existing_labs = [
        e for e in manifest.get("labyrinths", [])
        if not any(f"denny_{s}_" in e["id"] for s in SPACE_STORIES.keys())
    ]
    new_lab_entries = [
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
    manifest["labyrinths"] = existing_labs + new_lab_entries
    manifest["total"] = len(manifest["labyrinths"])

    # Add or replace space_adventures pack entry
    packs = [p for p in manifest.get("packs", []) if p.get("id") != "space_adventures"]
    packs.append({
        "id": "space_adventures",
        "title": "Denny in Space",
        "free_stories": 0,
        "stories": list(range(21, 41)),
    })
    manifest["packs"] = packs

    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest updated: {manifest_path} ({manifest['total']} entries)")
    print(f"Total space variants generated: {len(all_labs)}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate 'Denny in Space' pack (stories 021-030, 3 difficulty levels = 30 files)"
    )
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help="Output directory (default: output/labyrinths/)",
    )
    args = parser.parse_args()

    output_dir = (
        Path(args.output)
        if args.output
        else Path(__file__).parent / "output" / "labyrinths"
    )

    print(f"Generating Denny in Space pack -> {output_dir}")
    generate_space_variants(output_dir)
    print("\nDone! Next steps:")
    print("  1. Copy generated JSON files to LowDopamineLabyrinth/Resources/Labyrinths/")
    print("  2. Copy updated manifest.json to LowDopamineLabyrinth/Resources/Labyrinths/")
    print("  3. Add new files to Xcode project (drag into Resources/Labyrinths group)")
    print("  4. Generate space character images: python generate_characters.py --universe space")
    print("  5. Generate audio: python generator.py --generate-audio --output <dir>")


if __name__ == "__main__":
    main()
