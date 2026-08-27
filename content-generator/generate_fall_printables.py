#!/usr/bin/env python3
"""Generate fall-themed A4 printable maze SVGs.

The printable pages are intentionally separate from the app content bundle.
They reuse the existing FullMazeGenerator maze logic, then wrap the generated
maze paths in simple A4 SVG pages for website downloads.
"""

from __future__ import annotations

import html
import json
import base64
import random
import subprocess
import tempfile
import zipfile
from pathlib import Path
from typing import Any

from maze_generator import FullMazeGenerator


OUTPUT_DIR = Path(__file__).resolve().parents[1] / "content" / "printables" / "fall-mazes"
ASSET_DIR = OUTPUT_DIR / "assets"
DEFAULT_CHROME = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
WEBSITE = "www.harmlessapp.com/printables"
_ASSET_DATA_CACHE: dict[str, str] = {}

A4_WIDTH = 210
A4_HEIGHT = 297
MAZE_X = 24
MAZE_Y = 76
MAZE_WIDTH = 162
MAZE_HEIGHT = 145

DIFFICULTIES: dict[str, dict[str, Any]] = {
    "easy": {
        "label": "Easy",
        "rows": 5,
        "cols": 7,
        "stroke": 1.7,
        "item_count": 2,
        "avoid_count": 1,
    },
    "medium": {
        "label": "Medium",
        "rows": 8,
        "cols": 10,
        "stroke": 1.45,
        "item_count": 3,
        "avoid_count": 2,
    },
    "hard": {
        "label": "Hard",
        "rows": 12,
        "cols": 16,
        "stroke": 1.05,
        "item_count": 4,
        "avoid_count": 3,
    },
}

THEMES: list[dict[str, Any]] = [
    {
        "slug": "leaf-pile",
        "title": "Leaf Pile Maze",
        "story_setup": "A gust of wind scattered golden leaves across the park. Denny wants to get home before the path gets too crunchy.",
        "instruction": "Trace a path to the leaf pile without crossing the maze walls.",
        "fun_fact": "Fallen leaves break down and help feed the soil.",
        "completion_message": "Denny found the leaf pile and made it home through the windy park.",
        "task": "Trace a path to the leaf pile without crossing the maze walls.",
        "goal": "leaf pile",
        "mode": "plain",
        "shape": "rect",
        "start": "bottom_left",
        "end": "top_right",
        "item": None,
        "palette": {
            "bg": "#FFF8EA",
            "panel": "#FFFDF7",
            "maze_bg": "#FFF3D9",
            "line": "#7B4E2A",
            "accent": "#D9772E",
            "soft": "#F7C873",
        },
    },
    {
        "slug": "apple-basket",
        "title": "Apple Basket Maze",
        "story_setup": "Denny found an apple basket under a tree. A few shiny apples are hiding along the orchard path.",
        "instruction": "Collect the apples and bring them to the basket.",
        "fun_fact": "Apples float because about one quarter of an apple is air.",
        "completion_message": "Denny picked the apples and carried them carefully to the basket.",
        "task": "Collect the apples and bring them to the basket.",
        "goal": "basket",
        "mode": "collect",
        "shape": "rect",
        "start": "bottom_left",
        "end": "top_right",
        "item": "apple",
        "palette": {
            "bg": "#FFF7ED",
            "panel": "#FFFEFA",
            "maze_bg": "#FFEFD8",
            "line": "#6F4A2F",
            "accent": "#C9412D",
            "soft": "#8DBA5A",
        },
    },
    {
        "slug": "corn-maze",
        "title": "Corn Maze",
        "story_setup": "Denny found a tall corn maze at the fall fair. Golden ears of corn are tucked inside the winding rows.",
        "instruction": "Collect the corn and find the way out of the cob-shaped maze.",
        "fun_fact": "Each strand of corn silk connects to one corn kernel.",
        "completion_message": "Denny collected the corn and found the exit between the tall rows.",
        "task": "Collect the corn and find the way out of the cob-shaped maze.",
        "goal": "corn",
        "mode": "collect",
        "shape": "corn",
        "start": "bottom_left",
        "end": "top_right",
        "item": "corn",
        "palette": {
            "bg": "#FFF7DD",
            "panel": "#FFFDF8",
            "maze_bg": "#F8E8AF",
            "line": "#5F5727",
            "accent": "#D99B1E",
            "soft": "#7FAE44",
        },
    },
    {
        "slug": "pumpkin-patch",
        "title": "Pumpkin Patch Maze",
        "story_setup": "Denny found a bumpy pumpkin patch beside the farm path. Round orange pumpkins are waiting in the vines.",
        "instruction": "Collect the pumpkins and reach the big pumpkin at the end.",
        "fun_fact": "Pumpkins are fruits because they grow from flowers and hold seeds inside.",
        "completion_message": "Denny gathered the pumpkins and found the biggest one in the patch.",
        "task": "Collect the pumpkins and reach the big pumpkin at the end.",
        "goal": "pumpkin",
        "mode": "collect",
        "shape": "pumpkin",
        "start": "bottom_left",
        "end": "top_right",
        "item": "pumpkin",
        "palette": {
            "bg": "#FFF4E6",
            "panel": "#FFFDF8",
            "maze_bg": "#FFE6BF",
            "line": "#75451F",
            "accent": "#E6812D",
            "soft": "#6F9E56",
        },
    },
    {
        "slug": "acorn-trail",
        "title": "Acorn Shell Maze",
        "story_setup": "An autumn wind curled the path into a shell shape. Denny spotted a few acorns near the quiet leaf pile.",
        "instruction": "Follow the wide path, collect the acorns and reach the leaf pile.",
        "fun_fact": "Acorns are oak tree seeds, and one oak can grow thousands of them.",
        "completion_message": "Denny followed the shell path, gathered the acorns and reached the leaves.",
        "task": "Follow the wide path, collect the acorns and reach the leaf pile.",
        "goal": "leaf pile",
        "mode": "collect",
        "shape": "shell",
        "render_style": "corridor",
        "item_count_delta": -1,
        "start": "bottom_left",
        "end": "top_right",
        "item": "acorn",
        "palette": {
            "bg": "#F9F2E7",
            "panel": "#FFFDF8",
            "maze_bg": "#F4E1C8",
            "line": "#5D4228",
            "accent": "#9A6735",
            "soft": "#D9A45B",
        },
    },
    {
        "slug": "rainy-walk",
        "title": "Rainy Puddle Maze",
        "story_setup": "It started to rain while Denny was outside. He wants to get home dry before the puddles grow bigger.",
        "instruction": "Help Denny avoid the puddles and reach the umbrella.",
        "fun_fact": "Puddles form when rain collects in low spots on the ground.",
        "completion_message": "Denny tiptoed around the puddles and reached the umbrella still dry.",
        "task": "Help Denny avoid the puddles and reach the umbrella.",
        "goal": "umbrella",
        "mode": "avoid",
        "shape": "rect",
        "start": "bottom_left",
        "end": "top_right",
        "item": "puddle",
        "palette": {
            "bg": "#EEF7F6",
            "panel": "#FCFFFD",
            "maze_bg": "#E0F3F0",
            "line": "#315C64",
            "accent": "#4B9AAA",
            "soft": "#F3C84B",
        },
    },
]


def scale_path(path: str, source_width: float, source_height: float) -> str:
    """Wrap source path in an SVG transform rather than rewriting coordinates."""
    scale = min(MAZE_WIDTH / source_width, MAZE_HEIGHT / source_height)
    width = source_width * scale
    height = source_height * scale
    offset_x = MAZE_X + (MAZE_WIDTH - width) / 2
    offset_y = MAZE_Y + (MAZE_HEIGHT - height) / 2
    return f'translate({offset_x:.2f} {offset_y:.2f}) scale({scale:.4f})'


def esc(value: str) -> str:
    return html.escape(value, quote=True)


def wrap_text(value: str, max_chars: int) -> list[str]:
    words = value.split()
    lines: list[str] = []
    current: list[str] = []
    for word in words:
        candidate = " ".join([*current, word])
        if current and len(candidate) > max_chars:
            lines.append(" ".join(current))
            current = [word]
        else:
            current.append(word)
    if current:
        lines.append(" ".join(current))
    return lines


def text_lines(lines: list[str], x: float, start_y: float, size: float, fill: str, weight: str = "400") -> str:
    return "\n".join(
        f'  <text x="{x}" y="{start_y + i * (size + 2):.1f}" text-anchor="middle" '
        f'font-family="Arial, sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}">{esc(line)}</text>'
        for i, line in enumerate(lines)
    )


def asset_href(kind: str) -> str:
    if kind in _ASSET_DATA_CACHE:
        return _ASSET_DATA_CACHE[kind]

    asset_path = ASSET_DIR / f"{kind}.png"
    if not asset_path.exists():
        return f"../assets/{kind}.png"

    encoded = base64.b64encode(asset_path.read_bytes()).decode("ascii")
    href = f"data:image/png;base64,{encoded}"
    _ASSET_DATA_CACHE[kind] = href
    return href


def asset_svg(kind: str, x: float, y: float, size: float, palette: dict[str, str], badge: bool = True) -> str:
    radius = size * 0.52
    image = (
        f'<image href="{asset_href(kind)}" x="{x - size / 2:.2f}" y="{y - size / 2:.2f}" '
        f'width="{size:.2f}" height="{size:.2f}" preserveAspectRatio="xMidYMid meet"/>'
    )
    if not badge:
        return image
    return f"""
  <g>
    <circle cx="{x:.2f}" cy="{y:.2f}" r="{radius:.2f}" fill="#FFFDF7" stroke="{palette['soft']}" stroke-width="{size * 0.055:.2f}"/>
    {image}
  </g>"""


def denny_asset_svg(x: float, y: float, size: float, palette: dict[str, str]) -> str:
    if not (ASSET_DIR / "denny-raincoat.png").exists():
        return denny_svg(x, y, size / 72, True)
    return asset_svg("denny-raincoat", x, y, size, palette)


def icon_svg(kind: str, x: float, y: float, size: float, palette: dict[str, str]) -> str:
    accent = palette["accent"]
    soft = palette["soft"]
    line = palette["line"]

    if kind == "leaf":
        return f"""
  <g transform="translate({x} {y}) rotate(-20)">
    <ellipse cx="0" cy="0" rx="{size * 0.34}" ry="{size * 0.55}" fill="{accent}"/>
    <path d="M 0 {size * 0.5} C {-size * 0.05} {size * 0.15}, {size * 0.1} {-size * 0.2}, {size * 0.28} {-size * 0.48}" fill="none" stroke="{line}" stroke-width="{size * 0.045}" stroke-linecap="round"/>
  </g>"""
    if kind == "apple":
        return f"""
  <g transform="translate({x} {y})">
    <circle cx="{-size * 0.12}" cy="{size * 0.05}" r="{size * 0.28}" fill="{accent}"/>
    <circle cx="{size * 0.12}" cy="{size * 0.05}" r="{size * 0.28}" fill="{accent}"/>
    <path d="M 0 {-size * 0.24} Q {size * 0.18} {-size * 0.5} {size * 0.4} {-size * 0.34}" fill="{soft}"/>
    <path d="M 0 {-size * 0.22} L {size * 0.05} {-size * 0.48}" stroke="{line}" stroke-width="{size * 0.055}" stroke-linecap="round"/>
  </g>"""
    if kind == "pumpkin":
        return f"""
  <g transform="translate({x} {y})">
    <ellipse cx="{-size * 0.2}" cy="{size * 0.06}" rx="{size * 0.22}" ry="{size * 0.32}" fill="{accent}"/>
    <ellipse cx="{size * 0.2}" cy="{size * 0.06}" rx="{size * 0.22}" ry="{size * 0.32}" fill="{accent}"/>
    <ellipse cx="0" cy="{size * 0.06}" rx="{size * 0.25}" ry="{size * 0.36}" fill="#F29A33"/>
    <path d="M 0 {-size * 0.24} C {size * 0.06} {-size * 0.4}, {size * 0.18} {-size * 0.38}, {size * 0.12} {-size * 0.55}" fill="none" stroke="{line}" stroke-width="{size * 0.06}" stroke-linecap="round"/>
  </g>"""
    if kind == "acorn":
        return f"""
  <g transform="translate({x} {y})">
    <path d="M {-size * 0.28} {-size * 0.02} Q 0 {size * 0.62} {size * 0.28} {-size * 0.02} Z" fill="{soft}"/>
    <path d="M {-size * 0.34} {-size * 0.05} Q 0 {-size * 0.36} {size * 0.34} {-size * 0.05} Q 0 {size * 0.1} {-size * 0.34} {-size * 0.05}" fill="{accent}"/>
    <path d="M 0 {-size * 0.26} L {size * 0.08} {-size * 0.48}" stroke="{line}" stroke-width="{size * 0.055}" stroke-linecap="round"/>
  </g>"""
    if kind == "raindrop":
        return f"""
  <path d="M {x} {y - size * 0.52} C {x - size * 0.28} {y - size * 0.15}, {x - size * 0.34} {y + size * 0.08}, {x} {y + size * 0.42} C {x + size * 0.34} {y + size * 0.08}, {x + size * 0.28} {y - size * 0.15}, {x} {y - size * 0.52} Z" fill="{accent}"/>"""
    if kind == "basket":
        return f"""
  <g transform="translate({x} {y})">
    <path d="M {-size * 0.42} {-size * 0.1} L {size * 0.42} {-size * 0.1} L {size * 0.3} {size * 0.42} L {-size * 0.3} {size * 0.42} Z" fill="{soft}" stroke="{line}" stroke-width="{size * 0.045}"/>
    <path d="M {-size * 0.25} {-size * 0.1} Q 0 {-size * 0.58} {size * 0.25} {-size * 0.1}" fill="none" stroke="{line}" stroke-width="{size * 0.05}" stroke-linecap="round"/>
  </g>"""
    if kind == "porch":
        return f"""
  <g transform="translate({x} {y})">
    <path d="M {-size * 0.48} {size * 0.05} L 0 {-size * 0.42} L {size * 0.48} {size * 0.05} Z" fill="{accent}"/>
    <rect x="{-size * 0.36}" y="{size * 0.02}" width="{size * 0.72}" height="{size * 0.48}" rx="{size * 0.05}" fill="{soft}" stroke="{line}" stroke-width="{size * 0.04}"/>
  </g>"""
    if kind == "tree":
        return f"""
  <g transform="translate({x} {y})">
    <rect x="{-size * 0.08}" y="{size * 0.05}" width="{size * 0.16}" height="{size * 0.45}" fill="{line}"/>
    <circle cx="0" cy="{-size * 0.12}" r="{size * 0.34}" fill="{soft}"/>
    <circle cx="{-size * 0.24}" cy="0" r="{size * 0.24}" fill="{accent}"/>
    <circle cx="{size * 0.24}" cy="0" r="{size * 0.24}" fill="{accent}"/>
  </g>"""
    if kind == "umbrella":
        return f"""
  <g transform="translate({x} {y})">
    <path d="M {-size * 0.5} 0 Q 0 {-size * 0.55} {size * 0.5} 0 Z" fill="{soft}" stroke="{line}" stroke-width="{size * 0.04}"/>
    <path d="M 0 0 L 0 {size * 0.52} Q 0 {size * 0.68} {size * 0.18} {size * 0.58}" fill="none" stroke="{line}" stroke-width="{size * 0.055}" stroke-linecap="round"/>
  </g>"""

    return ""


def denny_svg(x: float, y: float, scale: float = 1.0, raincoat: bool = False) -> str:
    coat = "#F3C84B" if raincoat else "#F7A24D"
    shell = "#F26B4F"
    dark = "#49372D"
    return f"""
  <g transform="translate({x} {y}) scale({scale})">
    <ellipse cx="0" cy="8" rx="16" ry="13" fill="{shell}"/>
    <path d="M -13 5 Q 0 26 13 5 L 9 23 L -9 23 Z" fill="{coat}" opacity="0.95"/>
    <circle cx="-7" cy="2" r="2.2" fill="{dark}"/>
    <circle cx="7" cy="2" r="2.2" fill="{dark}"/>
    <path d="M -5 9 Q 0 13 5 9" fill="none" stroke="{dark}" stroke-width="1.5" stroke-linecap="round"/>
    <path d="M -13 6 C -25 2, -27 12, -18 15" fill="none" stroke="{shell}" stroke-width="4" stroke-linecap="round"/>
    <path d="M 13 6 C 25 2, 27 12, 18 15" fill="none" stroke="{shell}" stroke-width="4" stroke-linecap="round"/>
    <path d="M -8 -7 L -11 -16 M 8 -7 L 11 -16" stroke="{shell}" stroke-width="3" stroke-linecap="round"/>
    <circle cx="-11" cy="-17" r="3.5" fill="white" stroke="{shell}" stroke-width="1.5"/>
    <circle cx="11" cy="-17" r="3.5" fill="white" stroke="{shell}" stroke-width="1.5"/>
  </g>"""


def hero_svg() -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="700" viewBox="0 0 1200 700" role="img" aria-label="Denny wearing a yellow raincoat and holding an umbrella">
  <rect width="1200" height="700" fill="#FFF4D8"/>
  <circle cx="980" cy="120" r="78" fill="#F7C873"/>
  <path d="M 110 505 C 270 455, 450 545, 620 498 C 790 450, 920 520, 1090 475 L 1090 700 L 110 700 Z" fill="#E5C18D"/>
  {icon_svg("leaf", 160, 170, 66, {"accent": "#D9772E", "soft": "#F7C873", "line": "#7B4E2A"})}
  {icon_svg("apple", 1010, 360, 72, {"accent": "#C9412D", "soft": "#8DBA5A", "line": "#6F4A2F"})}
  {icon_svg("pumpkin", 230, 560, 92, {"accent": "#E6812D", "soft": "#6F9E56", "line": "#75451F"})}
  <g transform="translate(745 195) rotate(-10) scale(3.2)">
    <path d="M -40 0 Q 0 -48 40 0 Z" fill="#F3C84B" stroke="#49372D" stroke-width="2"/>
    <path d="M 0 0 L 0 55 Q 0 72 18 62" fill="none" stroke="#49372D" stroke-width="3" stroke-linecap="round"/>
  </g>
  {denny_svg(600, 350, 6.4, True)}
  <text x="600" y="82" text-anchor="middle" font-family="Arial, sans-serif" font-size="48" font-weight="700" fill="#49372D">Fall Mazes with Denny</text>
  <text x="600" y="135" text-anchor="middle" font-family="Arial, sans-serif" font-size="26" fill="#7B4E2A">Free printable A4 mazes for calm seasonal play</text>
</svg>
"""


def hero_image_svg() -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="700" viewBox="0 0 1200 700" role="img" aria-label="Denny wearing a yellow raincoat and holding an umbrella">
  <rect width="1200" height="700" fill="#FFF4D8"/>
  <image href="assets/hero-denny-yellow-raincoat.png" x="0" y="0" width="1200" height="700" preserveAspectRatio="xMidYMid meet"/>
</svg>
"""


def page_svg(theme: dict[str, Any], difficulty: str, maze: dict[str, Any]) -> str:
    palette = theme["palette"]
    diff = DIFFICULTIES[difficulty]
    transform = scale_path(
        maze["svg_path"],
        float(maze.get("canvas_width", 600)),
        float(maze.get("canvas_height", 500)),
    )
    item_transform = transform
    item_kind = theme.get("item")
    goal_kind = theme["goal"].replace("leaf pile", "leaf-pile")
    story_lines = wrap_text(theme["story_setup"], 88)[:2]
    instruction_lines = wrap_text(theme["instruction"], 74)[:1]
    fact_lines = wrap_text(theme["fun_fact"], 74)[:2]
    fact_box_height = 12 + len(fact_lines) * 5.2
    fact_box_y = 262 - fact_box_height
    fact_label_y = fact_box_y + 6.2
    fact_text_y = fact_box_y + 12.6

    decorations = "\n".join([
        asset_svg("leaf", 20, 34, 17, palette),
        asset_svg("apple", 188, 31, 16, palette),
    ])

    item_svgs = []
    for item in maze.get("items", []) if item_kind else []:
        item_svgs.append(
            f'<g transform="{item_transform}">{asset_svg(item_kind, item["x"], item["y"], 46, palette, badge=False)}</g>'
        )
    for item in maze.get("avoid_items", []):
        item_svgs.append(
            f'<g transform="{item_transform}">{asset_svg(item_kind or "puddle", item["x"], item["y"], 52, palette, badge=False)}</g>'
        )
    is_corridor = str(maze.get("maze_type", "")).startswith("corridor")
    maze_path_svg = (
        f'<path d="{esc(maze["svg_path"])}" fill="none" stroke="#FFFDF7" stroke-width="{maze.get("path_width", 25)}" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<path d="{esc(maze["svg_path"])}" fill="none" stroke="{palette["line"]}" stroke-width="{diff["stroke"] * 0.55:.2f}" stroke-linecap="round" stroke-linejoin="round" opacity="0.28"/>'
        if is_corridor
        else f'<path d="{esc(maze["svg_path"])}" fill="none" stroke="{palette["line"]}" stroke-width="{diff["stroke"]}" stroke-linecap="round" stroke-linejoin="round"/>'
    )

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="210mm" height="297mm" viewBox="0 0 210 297" role="img" aria-label="{esc(theme['title'])}, {esc(diff['label'])}">
  <rect width="210" height="297" fill="{palette['bg']}"/>
  <rect x="11" y="11" width="188" height="275" rx="6" fill="{palette['panel']}" stroke="{palette['soft']}" stroke-width="0.8"/>
  {decorations}
  <text x="105" y="27" text-anchor="middle" font-family="Arial, sans-serif" font-size="11.5" font-weight="700" fill="{palette['line']}">{esc(theme['title'])}</text>
  <text x="105" y="39" text-anchor="middle" font-family="Arial, sans-serif" font-size="5.5" font-weight="700" fill="{palette['accent']}">{esc(diff['label'])}</text>
{text_lines(story_lines, 105, 51, 4.5, palette['line'])}
{text_lines(instruction_lines, 105, 65, 4.9, palette['accent'], '700')}

  <rect x="{MAZE_X - 5}" y="{MAZE_Y - 5}" width="{MAZE_WIDTH + 10}" height="{MAZE_HEIGHT + 10}" rx="5" fill="{palette['maze_bg']}" stroke="{palette['soft']}" stroke-width="0.7"/>
  <g transform="{transform}">
    {maze_path_svg}
  </g>
  {''.join(item_svgs)}
  <g transform="{transform}">
    <circle cx="{maze['start_point']['x']}" cy="{maze['start_point']['y']}" r="18" fill="#FFFDF7" stroke="{palette['accent']}" stroke-width="2"/>
  </g>
  <g transform="{transform}">
    {denny_asset_svg(maze['start_point']['x'], maze['start_point']['y'], 52, palette)}
  </g>
  <g transform="{transform}">
    <circle cx="{maze['end_point']['x']}" cy="{maze['end_point']['y']}" r="17" fill="#FFFDF7" stroke="{palette['accent']}" stroke-width="2"/>
    {asset_svg(goal_kind, maze['end_point']['x'], maze['end_point']['y'], 42, palette)}
  </g>

  <rect x="29" y="{fact_box_y:.1f}" width="152" height="{fact_box_height:.1f}" rx="4" fill="{palette['bg']}" stroke="{palette['soft']}" stroke-width="0.8"/>
  <text x="105" y="{fact_label_y:.1f}" text-anchor="middle" font-family="Arial, sans-serif" font-size="4.2" font-weight="700" fill="{palette['accent']}">Fun fact</text>
{text_lines(fact_lines, 105, fact_text_y, 3.75, palette['line'])}
  <text x="105" y="274" text-anchor="middle" font-family="Arial, sans-serif" font-size="4.4" fill="{palette['line']}">Free printable maze from Denny's Maze App - {WEBSITE}</text>
</svg>
"""


def chrome_binary() -> Path | None:
    if DEFAULT_CHROME.exists():
        return DEFAULT_CHROME
    return None


def svg_to_pdf(svg_path: Path, pdf_path: Path) -> None:
    chrome = chrome_binary()
    if chrome is None:
        raise RuntimeError(
            "Google Chrome is required to generate printable PDFs. "
            f"Expected binary at {DEFAULT_CHROME}."
        )

    html_markup = f"""<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      @page {{ size: A4; margin: 0; }}
      html, body {{ margin: 0; width: 210mm; height: 297mm; }}
      object {{ display: block; width: 210mm; height: 297mm; }}
    </style>
  </head>
  <body>
    <object type="image/svg+xml" data="{svg_path.resolve().as_uri()}"></object>
  </body>
</html>
"""
    with tempfile.NamedTemporaryFile("w", suffix=".html", encoding="utf-8", delete=False) as wrapper:
        wrapper.write(html_markup)
        wrapper_path = Path(wrapper.name)

    try:
        subprocess.run(
            [
                str(chrome),
                "--headless",
                "--disable-gpu",
                "--no-sandbox",
                "--print-to-pdf-no-header",
                f"--print-to-pdf={pdf_path}",
                wrapper_path.as_uri(),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    finally:
        wrapper_path.unlink(missing_ok=True)


def generate() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    svg_dir = OUTPUT_DIR / "svg"
    pdf_dir = OUTPUT_DIR / "pdf"
    json_dir = OUTPUT_DIR / "json"
    svg_dir.mkdir(exist_ok=True)
    pdf_dir.mkdir(exist_ok=True)
    json_dir.mkdir(exist_ok=True)
    ASSET_DIR.mkdir(exist_ok=True)
    for stale in [*svg_dir.glob("*.svg"), *pdf_dir.glob("*.pdf"), *json_dir.glob("*.json")]:
        stale.unlink()

    maze_generator = FullMazeGenerator()
    manifest: dict[str, Any] = {
        "title": "Fall Mazes with Denny",
        "website": WEBSITE,
        "format": "A4 PDF printables with SVG previews",
        "hero": "hero-denny-yellow-raincoat.svg",
        "hero_image": "assets/hero-denny-yellow-raincoat.png",
        "total": 0,
        "mazes": [],
    }

    hero_markup = hero_image_svg() if (ASSET_DIR / "hero-denny-yellow-raincoat.png").exists() else hero_svg()
    (OUTPUT_DIR / "hero-denny-yellow-raincoat.svg").write_text(hero_markup, encoding="utf-8")

    for theme in THEMES:
        for difficulty, diff in DIFFICULTIES.items():
            random.seed(f"fall-printable-{theme['slug']}-{difficulty}")
            maze_kwargs: dict[str, Any] = {
                "difficulty": difficulty,
                "age": 5,
                "shape": theme["shape"],
                "canvas_width": 600,
                "canvas_height": 500,
                "override_rows": diff["rows"],
                "override_cols": diff["cols"],
                "render_style": "walls",
                "start_position": theme["start"],
                "end_position": theme["end"],
            }
            if theme.get("render_style"):
                maze_kwargs["render_style"] = theme["render_style"]
            if theme["mode"] in {"collect", "avoid"}:
                item_count = diff["avoid_count"] if theme["mode"] == "avoid" else diff["item_count"]
                item_count = max(1, item_count + int(theme.get("item_count_delta", 0)))
                maze_kwargs.update(
                    item_rule=theme["mode"],
                    item_count=item_count,
                    item_emoji=theme["item"],
                )
            maze = maze_generator.generate_maze(
                **maze_kwargs,
            )
            slug = f"{theme['slug']}-{difficulty}"
            svg_path = svg_dir / f"{slug}.svg"
            pdf_path = pdf_dir / f"{slug}.pdf"
            json_path = json_dir / f"{slug}.json"

            svg_path.write_text(page_svg(theme, difficulty, maze), encoding="utf-8")
            svg_to_pdf(svg_path, pdf_path)
            json_path.write_text(
                json.dumps(
                    {
                        "id": slug,
                        "title": theme["title"],
                        "difficulty": difficulty,
                        "task": theme["task"],
                        "story_setup": theme["story_setup"],
                        "instruction": theme["instruction"],
                        "fun_fact": theme["fun_fact"],
                        "completion_message": theme["completion_message"],
                        "mode": theme["mode"],
                        "shape": theme["shape"],
                        "website": WEBSITE,
                        "maze": maze,
                    },
                    indent=2,
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            manifest["mazes"].append({
                "id": slug,
                "title": theme["title"],
                "difficulty": difficulty,
                "mode": theme["mode"],
                "shape": theme["shape"],
                "svg": f"svg/{slug}.svg",
                "pdf": f"pdf/{slug}.pdf",
                "json": f"json/{slug}.json",
            })

    manifest["total"] = len(manifest["mazes"])
    for difficulty, diff in DIFFICULTIES.items():
        zip_path = OUTPUT_DIR / f"fall-mazes-{difficulty}.zip"
        with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for theme in THEMES:
                slug = f"{theme['slug']}-{difficulty}"
                archive.write(pdf_dir / f"{slug}.pdf", arcname=f"{slug}.pdf")
        manifest.setdefault("packs", []).append({
            "label": diff["label"],
            "difficulty": difficulty,
            "zip": f"fall-mazes-{difficulty}.zip",
        })

    (OUTPUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    (OUTPUT_DIR / "README.md").write_text(
        "# Fall Mazes with Denny\n\n"
        "Generated A4 PDF printables for Harmless Apps website content.\n\n"
        "- 6 fall themes\n"
        "- 3 difficulty levels per theme\n"
        "- Individual worksheets are PDFs, with SVG files kept for web previews\n"
        "- Includes plain, collect, shaped-shell and avoid maze variants\n"
        "- Footer includes `www.harmlessapp.com`\n"
        "- `json/` files keep maze metadata and solution paths for future web pages\n",
        encoding="utf-8",
    )

    print(f"Generated {manifest['total']} printable mazes in {OUTPUT_DIR}")


if __name__ == "__main__":
    generate()
