#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "LowDopamineLabyrinth" / "LowDopamineLabyrinth" / "Assets.xcassets"
LABYRINTHS = ROOT / "LowDopamineLabyrinth" / "LowDopamineLabyrinth" / "Resources" / "Labyrinths"


def hex_color(value: str) -> tuple[int, int, int, int]:
    value = value.strip().lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255)


def parse_path(path_data: str) -> list[tuple[str, list[float]]]:
    tokens = re.findall(r"[MLQZmlqz]|-?\d+(?:\.\d+)?", path_data)
    commands: list[tuple[str, list[float]]] = []
    idx = 0
    command = ""
    while idx < len(tokens):
        if re.match(r"[A-Za-z]", tokens[idx]):
            command = tokens[idx]
            idx += 1
        if command.upper() == "M" or command.upper() == "L":
            if idx + 1 >= len(tokens):
                break
            commands.append((command.upper(), [float(tokens[idx]), float(tokens[idx + 1])]))
            idx += 2
        elif command.upper() == "Q":
            if idx + 3 >= len(tokens):
                break
            commands.append((command.upper(), [float(tokens[idx]), float(tokens[idx + 1]), float(tokens[idx + 2]), float(tokens[idx + 3])]))
            idx += 4
        else:
            idx += 1
    return commands


def transform_point(x: float, y: float, scale: float, margin: float) -> tuple[float, float]:
    return (x * scale + margin, y * scale + margin)


def draw_path(draw: ImageDraw.ImageDraw, path_data: str, *, scale: float, margin: float, width: int, fill: tuple[int, int, int, int]) -> None:
    current: tuple[float, float] | None = None
    for command, values in parse_path(path_data):
        if command == "M":
            current = transform_point(values[0], values[1], scale, margin)
        elif command == "L" and current is not None:
            target = transform_point(values[0], values[1], scale, margin)
            draw.line([current, target], fill=fill, width=width, joint="curve")
            current = target
        elif command == "Q" and current is not None:
            control = transform_point(values[0], values[1], scale, margin)
            target = transform_point(values[2], values[3], scale, margin)
            points = []
            for i in range(25):
                t = i / 24
                x = (1 - t) ** 2 * current[0] + 2 * (1 - t) * t * control[0] + t**2 * target[0]
                y = (1 - t) ** 2 * current[1] + 2 * (1 - t) * t * control[1] + t**2 * target[1]
                points.append((x, y))
            draw.line(points, fill=fill, width=width, joint="curve")
            current = target


def draw_ocean_pattern(draw: ImageDraw.ImageDraw, width: int, height: int) -> None:
    wave_color = (255, 255, 255, 42)
    bubble_color = (255, 255, 255, 58)
    for i in range(7):
        y = height * (i + 1) / 8
        points = []
        for x in range(0, width + 1, 18):
            points.append((x, y + math.sin((x / width) * math.tau * 3 + i) * 14))
        draw.line(points, fill=wave_color, width=3)
    for x_frac, y_frac, radius in [
        (0.1, 0.18, 14), (0.26, 0.72, 20), (0.48, 0.28, 11),
        (0.72, 0.78, 17), (0.86, 0.16, 12), (0.16, 0.52, 15),
        (0.62, 0.55, 9), (0.9, 0.44, 18), (0.4, 0.9, 13),
    ]:
        cx, cy = width * x_frac, height * y_frac
        draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], outline=bubble_color, width=3)


def load_character(asset_name: str, size: int) -> Image.Image:
    image_path = ASSETS / f"{asset_name}.imageset" / f"{asset_name}@2x.png"
    image = Image.open(image_path).convert("RGBA")
    image.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    canvas.alpha_composite(image, ((size - image.width) // 2, (size - image.height) // 2))
    return canvas


def draw_marker(base: Image.Image, asset_name: str, point: dict, *, scale: float, margin: float, size: int, start: bool) -> None:
    x, y = transform_point(point["x"], point["y"], scale, margin)
    layer = Image.new("RGBA", base.size, (255, 255, 255, 0))
    draw = ImageDraw.Draw(layer)
    if start:
        pad = 8
        draw.ellipse(
            [x - size / 2 - pad, y - size / 2 - pad, x + size / 2 + pad, y + size / 2 + pad],
            fill=(255, 255, 255, 235),
            outline=(255, 255, 255, 255),
            width=4,
        )
    character = load_character(asset_name, size)
    layer.alpha_composite(character, (int(x - size / 2), int(y - size / 2)))
    base.alpha_composite(layer)


def draw_bubbles(draw: ImageDraw.ImageDraw, items: list[dict], *, scale: float, margin: float) -> None:
    for item in items:
        x, y = transform_point(item["x"], item["y"], scale, margin)
        radius = 22 * scale
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=(255, 255, 255, 55), outline=(255, 255, 255, 220), width=max(2, int(3 * scale)))
        draw.ellipse([x - radius * 0.35, y - radius * 0.35, x - radius * 0.05, y - radius * 0.05], fill=(255, 255, 255, 150))


def render(
    labyrinth_id: str,
    output: Path,
    size: int,
    *,
    transparent: bool = False,
    path_only: bool = False,
) -> None:
    data = json.loads((LABYRINTHS / f"{labyrinth_id}.json").read_text(encoding="utf-8"))
    path = data["path_data"]
    margin = size * 0.08
    scale = min((size - margin * 2) / path["canvas_width"], (size - margin * 2) / path["canvas_height"])
    canvas_w = int(path["canvas_width"] * scale + margin * 2)
    canvas_h = int(path["canvas_height"] * scale + margin * 2)

    background = (255, 255, 255, 0) if transparent else hex_color(data["visual_theme"]["background_color"])
    image = Image.new("RGBA", (canvas_w, canvas_h), background)
    draw = ImageDraw.Draw(image)
    if not transparent and not path_only:
        draw_ocean_pattern(draw, canvas_w, canvas_h)

    stroke_width = max(8, int(path["width"] * scale))
    draw_path(draw, path["svg_path"], scale=scale, margin=margin, width=stroke_width, fill=(255, 255, 255, 245))
    if not path_only:
        draw_bubbles(draw, path.get("items", []), scale=scale, margin=margin)

        marker_size = int(72 * scale)
        draw_marker(image, data["character_start"]["image_asset"], path["start_point"], scale=scale, margin=margin, size=marker_size, start=True)
        draw_marker(image, data["character_end"]["image_asset"], path["end_point"], scale=scale, margin=margin, size=marker_size, start=False)

    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", default="denny_013_easy")
    parser.add_argument("--output", required=True)
    parser.add_argument("--size", type=int, default=1400)
    parser.add_argument("--transparent", action="store_true")
    parser.add_argument("--path-only", action="store_true")
    args = parser.parse_args()
    render(args.id, Path(args.output), args.size, transparent=args.transparent, path_only=args.path_only)


if __name__ == "__main__":
    main()
