"""
Character Image Generator using OpenAI DALL-E 3 API.

Generates consistent children's book style character illustrations
for the Low Dopamine Labyrinth app.

Usage:
    python generate_characters.py
    python generate_characters.py --character denny
    python generate_characters.py --output path/to/output

Requires:
    OPENAI_API_KEY in .env file
    pip install openai python-dotenv requests
"""

import argparse
import json
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

try:
    from openai import OpenAI
except ImportError:
    print("Error: openai package not installed. Run: pip install openai")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Prompt strategy (documented for future regeneration)
#
# Style: "children's book illustration, soft watercolor style"
# - Consistent across ALL characters for visual cohesion
# - Circular composition (clipped to circle in the app)
# - Clean solid-color background matching character's theme color
# - Simple, friendly, big expressive eyes — aimed at ages 3-6
# - No text, no humans, no scary elements
#
# DALL-E 3 settings:
# - Model: dall-e-3
# - Size: 1024x1024 (square — will be clipped to circle)
# - Quality: standard (hd not needed for small markers)
# - Style: natural (not vivid — softer for kids)
# ---------------------------------------------------------------------------

STYLE_SUFFIX = (
    "Children's book illustration, soft watercolor style, "
    "simple and friendly, big expressive eyes, "
    "centered in frame, circular composition, "
    "clean solid colored background, "
    "no text, no humans, suitable for ages 3-6"
)


def load_universe() -> dict:
    path = Path(__file__).parent / "characters" / "denny_universe.json"
    with open(path) as f:
        return json.load(f)


def build_prompt(character: dict) -> str:
    """Build the full DALL-E prompt for a character."""
    # Use the image_prompt from universe as the base, replace the suffix
    base = character["image_prompt"]
    # Strip generic suffix if present and replace with our consistent one
    for remove in [
        ", transparent background",
        ", children's book illustration style, simple, friendly, transparent background",
        ", children's book illustration style, simple, friendly",
    ]:
        base = base.replace(remove, "")

    bg_color = character.get("color", "#4A90E2")
    return f"{base}, on a clean {bg_color} colored circular background, {STYLE_SUFFIX}"


def generate_character_image(
    client: OpenAI, name: str, prompt: str, output_dir: Path
) -> Path:
    """Generate a single character image via DALL-E 3."""
    output_path = output_dir / f"{name}.png"

    if output_path.exists():
        print(f"  Skipping {name} (already exists)")
        return output_path

    print(f"  Generating {name}...")
    print(f"    Prompt: {prompt[:100]}...")

    response = client.images.generate(
        model="dall-e-3",
        prompt=prompt,
        size="1024x1024",
        quality="standard",
        style="natural",
        n=1,
    )

    image_url = response.data[0].url

    # Download the image
    import requests

    img_response = requests.get(image_url, timeout=60)
    img_response.raise_for_status()

    with open(output_path, "wb") as f:
        f.write(img_response.content)

    print(f"    Saved: {output_path}")

    # Save the revised prompt (DALL-E 3 may revise it)
    if response.data[0].revised_prompt:
        meta_path = output_dir / f"{name}_prompt.txt"
        with open(meta_path, "w") as f:
            f.write(f"Original: {prompt}\n\nRevised: {response.data[0].revised_prompt}\n")

    return output_path


def copy_to_xcassets(name: str, source_png: Path, xcassets_dir: Path):
    """Copy generated PNG into the Xcode asset catalog imageset."""
    imageset_dir = xcassets_dir / f"{name}.imageset"
    imageset_dir.mkdir(parents=True, exist_ok=True)

    # Copy as 2x (1024px is good for 2x retina on ~400pt display)
    import shutil

    dest = imageset_dir / f"{name}@2x.png"
    shutil.copy2(source_png, dest)

    # Write Contents.json
    contents = {
        "images": [
            {"idiom": "universal", "scale": "1x"},
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    contents_path = imageset_dir / "Contents.json"
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)

    print(f"    Updated asset: {imageset_dir}")


def main():
    parser = argparse.ArgumentParser(description="Generate character images via DALL-E 3")
    parser.add_argument("--character", type=str, help="Generate only this character (by key)")
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help="Output directory for PNGs (default: output/characters/)",
    )
    parser.add_argument(
        "--install",
        action="store_true",
        help="Also copy generated images to Xcode Assets.xcassets",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print prompts without calling API",
    )

    args = parser.parse_args()
    load_dotenv()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key and not args.dry_run:
        print("Error: OPENAI_API_KEY not set in .env file")
        print("Add to content-generator/.env:")
        print("  OPENAI_API_KEY=sk-...")
        sys.exit(1)

    universe = load_universe()
    characters = universe["characters"]

    output_dir = Path(args.output) if args.output else Path(__file__).parent / "output" / "characters"
    output_dir.mkdir(parents=True, exist_ok=True)

    # Filter to single character if specified
    if args.character:
        if args.character not in characters:
            print(f"Error: Unknown character '{args.character}'")
            print(f"Available: {', '.join(characters.keys())}")
            sys.exit(1)
        char_items = [(args.character, characters[args.character])]
    else:
        char_items = list(characters.items())

    # Save all prompts for documentation
    prompts_doc = []

    if not args.dry_run:
        client = OpenAI(api_key=api_key)

    print(f"\nGenerating {len(char_items)} character images...\n")

    for name, char_data in char_items:
        prompt = build_prompt(char_data)
        prompts_doc.append({"character": name, "prompt": prompt})

        if args.dry_run:
            print(f"  {name}:")
            print(f"    {prompt}\n")
            continue

        try:
            png_path = generate_character_image(client, name, prompt, output_dir)

            if args.install and png_path.exists():
                xcassets = (
                    Path(__file__).parent.parent
                    / "LowDopamineLabyrinth"
                    / "LowDopamineLabyrinth"
                    / "Assets.xcassets"
                )
                copy_to_xcassets(name, png_path, xcassets)
        except Exception as e:
            print(f"    Error: {e}")
            continue

    # Save prompts documentation
    prompts_path = output_dir / "prompts.json"
    with open(prompts_path, "w") as f:
        json.dump(
            {
                "model": "dall-e-3",
                "size": "1024x1024",
                "quality": "standard",
                "style": "natural",
                "style_suffix": STYLE_SUFFIX,
                "characters": prompts_doc,
            },
            f,
            indent=2,
        )
    print(f"\nPrompts saved: {prompts_path}")
    print("Done!")


if __name__ == "__main__":
    main()
