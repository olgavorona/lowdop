"""
Offline labyrinth content generator - produces 30 starter labyrinths
using pre-written story templates (no API key required).

Run: python generate_offline.py
"""

import json
import os
import random
from pathlib import Path

import yaml
from maze_generator import FullMazeGenerator

STORIES = {
    # === EASY (ages 3-4): 10 stories ===
    "animals": [
        {
            "title": "The Little Kitten",
            "story_setup": "A tiny gray kitten wandered away from the warm blanket.",
            "instruction": "Help the kitten find her way back to the cozy blanket.",
            "tts_instruction": "Use your finger to trace a path and help the little kitten get back to her blanket.",
            "character_start": {"type": "kitten", "description": "Small gray kitten with big eyes", "position": "bottom_left"},
            "character_end": {"type": "blanket", "description": "Soft red blanket in a basket", "position": "top_right"},
            "educational_question": "What sounds do kittens make? Can you purr like a kitten?",
            "fun_fact": "Kittens sleep for about 18 hours every day!",
            "completion_message": "The kitten is warm and cozy again. Good job helping!",
        },
        {
            "title": "The Hungry Bunny",
            "story_setup": "A little brown bunny is looking for a tasty carrot.",
            "instruction": "Help the bunny hop to the carrot.",
            "tts_instruction": "Trace the path with your finger to help the bunny find the yummy carrot.",
            "character_start": {"type": "bunny", "description": "Small brown bunny with floppy ears", "position": "bottom_left"},
            "character_end": {"type": "carrot", "description": "Big orange carrot with green leaves", "position": "top_right"},
            "educational_question": "What other vegetables do bunnies like to eat?",
            "fun_fact": "Bunnies can move their ears in different directions to listen for sounds!",
            "completion_message": "Yum! The bunny found the carrot. Thank you for helping!",
        },
    ],
    "nature": [
        {
            "title": "The Friendly Ladybug",
            "story_setup": "A little red ladybug wants to reach her favorite flower.",
            "instruction": "Help the ladybug fly to the big sunflower.",
            "tts_instruction": "Use your finger to show the ladybug the way to the pretty sunflower.",
            "character_start": {"type": "ladybug", "description": "Red ladybug with black spots", "position": "bottom_left"},
            "character_end": {"type": "sunflower", "description": "Tall yellow sunflower", "position": "top_right"},
            "educational_question": "How many spots can you count on a ladybug?",
            "fun_fact": "Ladybugs can eat up to 50 tiny bugs called aphids every single day!",
            "completion_message": "The ladybug is resting on the sunflower. How peaceful!",
        },
        {
            "title": "The Baby Turtle",
            "story_setup": "A baby turtle hatched on the beach and needs to reach the water.",
            "instruction": "Help the baby turtle get to the ocean.",
            "tts_instruction": "Trace the path to help the little turtle reach the cool ocean water.",
            "character_start": {"type": "baby_turtle", "description": "Tiny green turtle on sand", "position": "bottom_left"},
            "character_end": {"type": "ocean", "description": "Blue ocean waves", "position": "top_right"},
            "educational_question": "Why do you think turtles carry their house on their back?",
            "fun_fact": "Sea turtles can hold their breath underwater for a very long time!",
            "completion_message": "Splash! The baby turtle made it to the ocean. Well done!",
        },
    ],
    "home": [
        {
            "title": "Finding Teddy Bear",
            "story_setup": "It's bedtime, but Teddy Bear is lost somewhere in the house.",
            "instruction": "Help the child find Teddy Bear for bedtime.",
            "tts_instruction": "Trace the path to help find Teddy Bear so everyone can go to sleep.",
            "character_start": {"type": "child", "description": "Sleepy child in pajamas", "position": "bottom_left"},
            "character_end": {"type": "teddy", "description": "Brown teddy bear sitting on a shelf", "position": "top_right"},
            "educational_question": "Do you have a favorite stuffed animal? What is it?",
            "fun_fact": "The teddy bear was named after President Theodore Roosevelt!",
            "completion_message": "Teddy Bear found! Now it's time for a cozy sleep.",
        },
    ],
    "family": [
        {
            "title": "Grandma's House",
            "story_setup": "It's a sunny day to visit Grandma who baked cookies.",
            "instruction": "Help the child walk to Grandma's house.",
            "tts_instruction": "Use your finger to trace the path to Grandma's house. She has fresh cookies!",
            "character_start": {"type": "child", "description": "Happy child with a backpack", "position": "bottom_left"},
            "character_end": {"type": "grandma", "description": "Grandma at her front door waving", "position": "top_right"},
            "educational_question": "What is your favorite thing to do with your grandparents?",
            "fun_fact": "In some countries, grandchildren and grandparents live in the same house!",
            "completion_message": "You made it to Grandma's house! The cookies smell wonderful.",
        },
    ],
    "garden": [
        {
            "title": "The Watering Can",
            "story_setup": "The flowers in the garden are thirsty and need water.",
            "instruction": "Help bring the watering can to the flowers.",
            "tts_instruction": "Trace the path to bring water to the thirsty flowers.",
            "character_start": {"type": "watering_can", "description": "Blue watering can full of water", "position": "bottom_left"},
            "character_end": {"type": "flowers", "description": "Colorful flowers in a garden bed", "position": "top_right"},
            "educational_question": "What do plants need to grow? Can you name three things?",
            "fun_fact": "Sunflowers actually turn to face the sun as it moves across the sky!",
            "completion_message": "The flowers got their water. They look so happy now!",
        },
    ],
    "pets": [
        {
            "title": "Puppy's Walk",
            "story_setup": "A happy puppy is ready for his afternoon walk in the park.",
            "instruction": "Help the puppy walk to the park.",
            "tts_instruction": "Trace the path to take the little puppy on a walk to the park.",
            "character_start": {"type": "puppy", "description": "Golden puppy wagging its tail", "position": "bottom_left"},
            "character_end": {"type": "park", "description": "Green park with a big tree", "position": "top_right"},
            "educational_question": "What things does a puppy need to be happy and healthy?",
            "fun_fact": "Dogs wag their tails to the right when they are happy!",
            "completion_message": "The puppy loves the park! What a nice walk.",
        },
    ],
    "farm": [
        {
            "title": "The Lost Chick",
            "story_setup": "A fluffy yellow chick got separated from the mother hen.",
            "instruction": "Help the chick find the mother hen.",
            "tts_instruction": "Use your finger to help the baby chick get back to its mommy.",
            "character_start": {"type": "chick", "description": "Fluffy yellow baby chick", "position": "bottom_left"},
            "character_end": {"type": "hen", "description": "Brown mother hen by the coop", "position": "top_right"},
            "educational_question": "What other baby animals live on a farm?",
            "fun_fact": "Baby chicks start talking to their mother while still inside the egg!",
            "completion_message": "The chick found its mommy! They are together again.",
        },
    ],
    # === MEDIUM (ages 4-5): 10 stories ===
    "adventures": [
        {
            "title": "The Treasure Map",
            "story_setup": "An explorer found an old map that leads to a hidden treasure chest.",
            "instruction": "Follow the map path to find the treasure.",
            "tts_instruction": "Trace the path on the treasure map to find where the treasure is hidden.",
            "character_start": {"type": "explorer", "description": "Child explorer with a hat and magnifying glass", "position": "bottom_left"},
            "character_end": {"type": "treasure", "description": "Wooden treasure chest with gold coins", "position": "top_right"},
            "educational_question": "If you found a treasure chest, what would you hope was inside?",
            "fun_fact": "Real treasure maps were used by pirates hundreds of years ago!",
            "completion_message": "You found the treasure! What an amazing adventure.",
        },
    ],
    "seasons": [
        {
            "title": "The First Snowflake",
            "story_setup": "Winter is coming and the first snowflake is falling from the sky.",
            "instruction": "Help the snowflake land gently on the ground.",
            "tts_instruction": "Trace the path to help the snowflake float down to the ground.",
            "character_start": {"type": "snowflake", "description": "Sparkly white snowflake", "position": "top_left"},
            "character_end": {"type": "ground", "description": "Snowy ground with a snowman", "position": "bottom_right"},
            "educational_question": "What are the four seasons? Which one is your favorite?",
            "fun_fact": "Every single snowflake has a different shape. No two are exactly alike!",
            "completion_message": "The snowflake landed softly. Let's build a snowman!",
        },
    ],
    "weather": [
        {
            "title": "Rainbow Bridge",
            "story_setup": "After the rain, a beautiful rainbow appeared in the sky.",
            "instruction": "Follow the rainbow from one end to the other.",
            "tts_instruction": "Trace the path along the rainbow from one side of the sky to the other.",
            "character_start": {"type": "cloud", "description": "Fluffy rain cloud with a smile", "position": "bottom_left"},
            "character_end": {"type": "sun", "description": "Warm yellow sun peeking through clouds", "position": "top_right"},
            "educational_question": "Can you name the colors in a rainbow?",
            "fun_fact": "Rainbows happen when sunlight passes through tiny raindrops in the air!",
            "completion_message": "What a beautiful rainbow! The sun is shining again.",
        },
    ],
    "playground": [
        {
            "title": "The Big Slide",
            "story_setup": "It's recess time and the playground is waiting!",
            "instruction": "Help the child get to the big slide.",
            "tts_instruction": "Trace the path to help the child reach the fun slide at the playground.",
            "character_start": {"type": "child", "description": "Excited child ready to play", "position": "bottom_left"},
            "character_end": {"type": "slide", "description": "Tall colorful playground slide", "position": "top_right"},
            "educational_question": "What is your favorite thing to do at the playground?",
            "fun_fact": "The first playground slide was invented over 100 years ago!",
            "completion_message": "Whee! What a fun slide! Time to play!",
        },
    ],
    "fairy_tales": [
        {
            "title": "The Magic Wand",
            "story_setup": "A young fairy lost her magic wand in the enchanted forest.",
            "instruction": "Help the fairy find her magic wand.",
            "tts_instruction": "Trace the path through the enchanted forest to help the fairy find her wand.",
            "character_start": {"type": "fairy", "description": "Small fairy with sparkly wings", "position": "bottom_left"},
            "character_end": {"type": "wand", "description": "Glowing magic wand with a star on top", "position": "top_right"},
            "educational_question": "If you had a magic wand, what nice thing would you do?",
            "fun_fact": "In stories, fairies are often the size of your hand!",
            "completion_message": "The fairy found her wand! Now the forest is sparkly again.",
        },
    ],
    "helping_others": [
        {
            "title": "The Kind Neighbor",
            "story_setup": "Mrs. Chen needs help carrying her groceries home.",
            "instruction": "Help carry the groceries to Mrs. Chen's house.",
            "tts_instruction": "Trace the path to help bring the groceries to the neighbor's house.",
            "character_start": {"type": "child_helper", "description": "Kind child carrying a grocery bag", "position": "bottom_left"},
            "character_end": {"type": "house", "description": "Mrs. Chen waving from her doorstep", "position": "top_right"},
            "educational_question": "How can you help someone in your neighborhood today?",
            "fun_fact": "Helping others actually makes your own brain feel happy too!",
            "completion_message": "Mrs. Chen is so thankful! Helping others feels wonderful.",
        },
    ],
    "music": [
        {
            "title": "The Dancing Notes",
            "story_setup": "Musical notes escaped from the piano and need to get back.",
            "instruction": "Help the music notes return to the piano.",
            "tts_instruction": "Trace the path to guide the music notes back to the piano.",
            "character_start": {"type": "music_note", "description": "Bouncy colorful music note", "position": "bottom_left"},
            "character_end": {"type": "piano", "description": "Friendly-looking upright piano", "position": "top_right"},
            "educational_question": "What is your favorite instrument? Can you name three instruments?",
            "fun_fact": "Music can make plants grow faster!",
            "completion_message": "The notes are back! Listen to the beautiful melody.",
        },
    ],
    "bugs": [
        {
            "title": "The Busy Ant",
            "story_setup": "A hardworking ant found a big crumb and needs to bring it to the anthill.",
            "instruction": "Help the ant carry the crumb to the anthill.",
            "tts_instruction": "Trace the path to help the little ant bring food back to its family.",
            "character_start": {"type": "ant", "description": "Small black ant carrying a crumb", "position": "bottom_left"},
            "character_end": {"type": "anthill", "description": "Brown anthill with tiny ants waving", "position": "top_right"},
            "educational_question": "How do you think ants work together as a team?",
            "fun_fact": "Ants can carry things that are 50 times heavier than themselves!",
            "completion_message": "The ant brought food to its family. Teamwork!",
        },
    ],
    "birds": [
        {
            "title": "Flying Home",
            "story_setup": "A baby bird learned to fly and now it's time to go back to the nest.",
            "instruction": "Help the baby bird fly back to its nest.",
            "tts_instruction": "Trace the path to help the baby bird fly home to the cozy nest.",
            "character_start": {"type": "baby_bird", "description": "Small blue bird with tiny wings", "position": "bottom_left"},
            "character_end": {"type": "nest", "description": "Warm nest in a tree with mama bird", "position": "top_right"},
            "educational_question": "What do birds use to build their nests?",
            "fun_fact": "Some birds can fly without stopping for thousands of miles!",
            "completion_message": "The baby bird is home safe! Mama bird is so happy.",
        },
    ],
    # === HARD (ages 5-6): 10 stories ===
    "space": [
        {
            "title": "Moon Mission",
            "story_setup": "An astronaut is on a mission to explore the moon.",
            "instruction": "Guide the rocket ship to land safely on the moon.",
            "tts_instruction": "Trace the path to help the rocket ship land on the moon.",
            "character_start": {"type": "rocket", "description": "Red and white rocket ship with flames", "position": "bottom_left"},
            "character_end": {"type": "moon", "description": "Smiling moon with craters", "position": "top_right"},
            "educational_question": "What do you think astronauts eat in space?",
            "fun_fact": "Footprints left on the moon will stay there for millions of years because there is no wind!",
            "completion_message": "Houston, we have landed! The moon is beautiful up close.",
        },
        {
            "title": "Star Collector",
            "story_setup": "A little alien is collecting stars to decorate their planet.",
            "instruction": "Help the alien reach the brightest star.",
            "tts_instruction": "Trace the path to help the friendly alien reach the shining star.",
            "character_start": {"type": "alien", "description": "Small green alien with big friendly eyes", "position": "bottom_left"},
            "character_end": {"type": "star", "description": "Bright golden star glowing", "position": "top_right"},
            "educational_question": "How many stars do you think are in the sky?",
            "fun_fact": "Our sun is actually a star! It just looks bigger because it is close to us.",
            "completion_message": "The alien caught the star! Its planet will sparkle tonight.",
        },
    ],
    "ocean": [
        {
            "title": "The Lost Dolphin",
            "story_setup": "A baby dolphin swam too far from its family pod.",
            "instruction": "Help the baby dolphin find its mother.",
            "tts_instruction": "Trace the underwater path to help the baby dolphin swim back to its family.",
            "character_start": {"type": "baby_dolphin", "description": "Small gray dolphin looking worried", "position": "bottom_left"},
            "character_end": {"type": "mother_dolphin", "description": "Large dolphin with open flippers", "position": "top_right"},
            "educational_question": "Why do dolphins swim together in groups?",
            "fun_fact": "Dolphins can recognize themselves in mirrors, just like people!",
            "completion_message": "The baby dolphin found its family! They splashed with joy.",
        },
    ],
    "community": [
        {
            "title": "The Fire Station",
            "story_setup": "The firefighters heard an alarm and need to reach the fire truck.",
            "instruction": "Help the firefighter get to the fire truck quickly.",
            "tts_instruction": "Trace the path to help the firefighter reach the fire truck.",
            "character_start": {"type": "firefighter", "description": "Brave firefighter in yellow gear", "position": "bottom_left"},
            "character_end": {"type": "firetruck", "description": "Shiny red fire truck with ladder", "position": "top_right"},
            "educational_question": "What do firefighters do to keep us safe?",
            "fun_fact": "Dalmatian dogs used to run alongside fire trucks to help clear the way!",
            "completion_message": "The firefighter is ready to help! What a brave team.",
        },
    ],
    "dinosaurs": [
        {
            "title": "The Dino Nest",
            "story_setup": "A baby dinosaur hatched and needs to find its mother.",
            "instruction": "Help the baby dinosaur walk to the mother dinosaur.",
            "tts_instruction": "Trace the path to help the baby dinosaur find its mommy.",
            "character_start": {"type": "baby_dino", "description": "Small green dinosaur just hatched from egg", "position": "bottom_left"},
            "character_end": {"type": "mama_dino", "description": "Large gentle dinosaur waiting by nest", "position": "top_right"},
            "educational_question": "What do you think dinosaurs ate for breakfast?",
            "fun_fact": "Some dinosaurs were as small as chickens!",
            "completion_message": "The baby dino found its mommy! They nuzzled noses.",
        },
    ],
    "transportation": [
        {
            "title": "Train Journey",
            "story_setup": "The train needs to reach the station to pick up passengers.",
            "instruction": "Guide the train along the tracks to the station.",
            "tts_instruction": "Trace the path along the train tracks to reach the station.",
            "character_start": {"type": "train", "description": "Colorful steam train chugging along", "position": "bottom_left"},
            "character_end": {"type": "station", "description": "Red train station with passengers waiting", "position": "top_right"},
            "educational_question": "What different types of transportation can you think of?",
            "fun_fact": "The fastest trains in the world can go over 300 miles per hour!",
            "completion_message": "All aboard! The train arrived right on time.",
        },
    ],
    "recycling": [
        {
            "title": "Sort and Save",
            "story_setup": "A plastic bottle fell out of the recycling bin and needs to go back.",
            "instruction": "Help the bottle get to the recycling bin.",
            "tts_instruction": "Trace the path to put the bottle in the right recycling bin.",
            "character_start": {"type": "bottle", "description": "Blue plastic water bottle", "position": "bottom_left"},
            "character_end": {"type": "recycling_bin", "description": "Green recycling bin with arrows", "position": "top_right"},
            "educational_question": "What things in your house can be recycled?",
            "fun_fact": "Recycling one plastic bottle saves enough energy to power a light bulb for 3 hours!",
            "completion_message": "Great recycling! You are helping the Earth stay clean.",
        },
    ],
    "world_cultures": [
        {
            "title": "Around the World",
            "story_setup": "A letter needs to travel across the ocean to reach a pen pal.",
            "instruction": "Help the letter travel to the pen pal's mailbox.",
            "tts_instruction": "Trace the path to deliver the letter to a friend across the ocean.",
            "character_start": {"type": "letter", "description": "Colorful envelope with stamps", "position": "bottom_left"},
            "character_end": {"type": "mailbox", "description": "Red mailbox in front of a house", "position": "top_right"},
            "educational_question": "If you could send a letter to anyone in the world, who would it be?",
            "fun_fact": "People have been sending letters for over 4,000 years!",
            "completion_message": "The letter arrived! Your pen pal will be so happy to read it.",
        },
    ],
    "inventions": [
        {
            "title": "The Light Bulb",
            "story_setup": "The inventor has an idea but needs to reach the workshop to build it.",
            "instruction": "Help the inventor get to the workshop.",
            "tts_instruction": "Trace the path to help the inventor reach the workshop and build something amazing.",
            "character_start": {"type": "inventor", "description": "Curious child with goggles and notebook", "position": "bottom_left"},
            "character_end": {"type": "workshop", "description": "Workshop with tools and a light bulb", "position": "top_right"},
            "educational_question": "If you could invent anything, what would you create?",
            "fun_fact": "Thomas Edison tried over 1,000 times before his light bulb worked!",
            "completion_message": "The inventor made it! Time to create something wonderful.",
        },
    ],
    "sports": [
        {
            "title": "Goal Time",
            "story_setup": "The soccer ball rolled away from the field during practice.",
            "instruction": "Help kick the ball back to the goal.",
            "tts_instruction": "Trace the path to help the soccer ball roll into the goal.",
            "character_start": {"type": "soccer_ball", "description": "Black and white soccer ball", "position": "bottom_left"},
            "character_end": {"type": "goal", "description": "Soccer goal with a net", "position": "top_right"},
            "educational_question": "What is your favorite sport or game to play outside?",
            "fun_fact": "Soccer is played in almost every country in the world!",
            "completion_message": "Goal! What a fantastic kick!",
        },
    ],
}


def get_story(theme: str, index: int) -> dict:
    stories = STORIES.get(theme, [])
    if not stories:
        # Fallback
        return {
            "title": f"The {theme.title()} Path",
            "story_setup": f"Let's explore the {theme} together.",
            "instruction": f"Trace the path through the {theme}.",
            "tts_instruction": f"Use your finger to trace the path through the {theme}.",
            "character_start": {"type": "child", "description": "A curious child", "position": "bottom_left"},
            "character_end": {"type": "star", "description": "A shining star", "position": "top_right"},
            "educational_question": f"What do you know about {theme}?",
            "fun_fact": f"There are so many interesting things about {theme}!",
            "completion_message": "Great job! You finished the path.",
        }
    return stories[index % len(stories)]


def main():
    config_path = Path(__file__).parent / "config.yaml"
    with open(config_path) as f:
        config = yaml.safe_load(f)

    output_dir = Path(__file__).parent / "output" / "labyrinths"
    output_dir.mkdir(parents=True, exist_ok=True)
    svg_dir = Path(__file__).parent / "output" / "svg_previews"
    svg_dir.mkdir(parents=True, exist_ok=True)

    maze_gen = FullMazeGenerator()
    visual_themes = config.get("visual_themes", {})
    all_labs = []

    batches = [
        # (count, age, difficulty, themes_key, shapes, start_id)
        (10, 3, "easy", "young", ["rect"], 1),
        (10, 5, "medium", "middle", ["rect", "triangle", "tree"], 11),
        (10, 6, "hard", "older", ["rect", "triangle", "tree", "mountain", "diamond", "circle"], 21),
    ]

    for count, age, difficulty, group_key, shapes, start_id in batches:
        themes = config["age_groups"][group_key]["themes"]
        print(f"\n=== Generating {difficulty.upper()} labyrinths (age {age}) ===")
        for i in range(count):
            theme = themes[i % len(themes)]
            shape = shapes[i % len(shapes)]
            lab_id = f"lab_{start_id + i:03d}"

            story = get_story(theme, i)
            maze_data = maze_gen.generate_maze(
                difficulty=difficulty, age=age, shape=shape,
                canvas_width=600, canvas_height=500,
            )

            vt = visual_themes.get(theme, {"background_color": "#4A90E2", "decorative_elements": ["stars"]})

            labyrinth = {
                "id": lab_id,
                "age_range": f"{age}-{age+1}" if age < 6 else "5-6",
                "difficulty": difficulty,
                "theme": theme,
                "title": story["title"],
                "story_setup": story["story_setup"],
                "instruction": story["instruction"],
                "tts_instruction": story["tts_instruction"],
                "character_start": story["character_start"],
                "character_end": story["character_end"],
                "educational_question": story["educational_question"],
                "fun_fact": story["fun_fact"],
                "completion_message": story["completion_message"],
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
            }
            all_labs.append(labyrinth)

            # Save JSON
            json_path = output_dir / f"{lab_id}.json"
            with open(json_path, "w") as f:
                json.dump(labyrinth, f, indent=2)

            # Save SVG preview
            svg = maze_gen.to_full_svg(maze_data, vt["background_color"])
            svg_path = svg_dir / f"{lab_id}.svg"
            with open(svg_path, "w") as f:
                f.write(svg)

            print(f"  Generated: {lab_id} ({theme}, {shape})")

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
    with open(output_dir / "manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"\nDone! Generated {len(all_labs)} labyrinths.")
    print(f"JSON files: {output_dir}")
    print(f"SVG previews: {svg_dir}")


if __name__ == "__main__":
    main()
