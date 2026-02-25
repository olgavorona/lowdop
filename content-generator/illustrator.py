"""
Character Illustrator for Denny Universe.

Generates image prompts and provides fallback emoji mapping
for all characters in the Denny the Baby Crab universe.
"""

import json
from pathlib import Path


def load_universe():
    path = Path(__file__).parent / "characters" / "denny_universe.json"
    with open(path) as f:
        return json.load(f)


# Fallback emoji mapping for characters (used when image assets aren't available)
CHARACTER_EMOJI = {
    "denny": "\ud83e\udd80",
    "mama_coral": "\ud83e\udd80",
    "daddy_reef": "\ud83e\udd80",
    "sandy": "\ud83e\udd80",
    "finn": "\ud83d\udc20",
    "stella": "\u2b50",
    "ollie": "\ud83d\udc19",
    "shelly": "\ud83d\udc22",
    "bubbles": "\ud83e\udee7",
    "pearl": "\ud83e\udeb4",
}


def get_image_prompts():
    """Return dict of character_key -> image_prompt for generation."""
    universe = load_universe()
    return {
        key: char["image_prompt"]
        for key, char in universe["characters"].items()
    }


def main():
    """Print image generation prompts for all characters."""
    prompts = get_image_prompts()
    universe = load_universe()

    print("=== Denny Universe Character Image Prompts ===\n")
    for key, prompt in prompts.items():
        char = universe["characters"][key]
        print(f"Character: {char['name']} ({key})")
        print(f"  Emoji fallback: {CHARACTER_EMOJI[key]}")
        print(f"  Image prompt: {prompt}")
        print()

    print("\n=== Emoji Fallback Mapping ===")
    print(json.dumps(CHARACTER_EMOJI, indent=2))


if __name__ == "__main__":
    main()
