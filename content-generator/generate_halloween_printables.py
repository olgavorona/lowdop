#!/usr/bin/env python3
"""Generate gentle Halloween-themed A4 printable maze SVGs.

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
import time
import zipfile
from pathlib import Path
from typing import Any

from maze_generator import FullMazeGenerator


OUTPUT_DIR = Path(__file__).resolve().parents[1] / "content" / "printables" / "halloween-mazes"
ASSET_DIR = OUTPUT_DIR / "assets"
BW_ASSET_DIR = OUTPUT_DIR / "assets-bw"
DEFAULT_CHROME = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
WEBSITE = "www.harmlessapp.com/printables/halloween"
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
        "slug": "pumpkin-patch", "title": "Pumpkin Patch Maze",
        "story_setup": "Denny put on a black-cat costume and found a moonlit pumpkin patch. Little pumpkins glow beside the winding path.",
        "instruction": "Collect the pumpkins and reach the smiling jack-o'-lantern.",
        "fun_fact": "Pumpkins are fruits because they grow from flowers and hold seeds inside.",
        "completion_message": "Denny gathered the pumpkins and reached the smiling jack-o'-lantern.",
        "task": "Collect the pumpkins and reach the jack-o'-lantern.",
        "goal": "jack-o-lantern", "mode": "collect", "shape": "rect",
        "start": "bottom_left", "end": "top_right", "item": "pumpkin",
        "palette": {"bg": "#FFF8EE", "panel": "#FFFFFF", "maze_bg": "#FFF0D8", "line": "#34213F", "accent": "#E56A2E", "soft": "#FFB34D"},
    },
    {
        "slug": "jack-o-lantern", "title": "Jack-o'-Lantern Maze",
        "story_setup": "A smiling jack-o'-lantern lit up a pumpkin-shaped path. Denny spotted a candy bucket waiting on the other side.",
        "instruction": "Follow the pumpkin-shaped maze and reach the candy bucket.",
        "fun_fact": "People once carved lanterns from turnips before pumpkins became popular.",
        "completion_message": "Denny followed the lantern light and found the candy bucket.",
        "task": "Cross the pumpkin-shaped maze and find the candy bucket.",
        "goal": "candy-bucket", "mode": "plain", "shape": "pumpkin",
        "start": "bottom_left", "end": "top_right", "item": None,
        "palette": {"bg": "#F9F3FF", "panel": "#FFFFFF", "maze_bg": "#F2E6FF", "line": "#332148", "accent": "#F0782F", "soft": "#B794F6"},
    },
    {
        "slug": "spooky-house", "title": "Spooky House Maze",
        "story_setup": "Denny found a tiny Halloween house with warm windows and a crooked roof. A cozy light shines behind the house-shaped paths.",
        "instruction": "Find a path through the house-shaped maze to the front door.",
        "fun_fact": "A house roof helps rain run off instead of collecting on top.",
        "completion_message": "Denny followed the warm windows and found the cozy front door.",
        "task": "Find a path through the house-shaped maze to the front door.",
        "goal": "spooky-house", "mode": "plain", "shape": "house",
        "start": "bottom_left", "end": "top_right", "item": None,
        "palette": {"bg": "#F2F4FF", "panel": "#FFFFFF", "maze_bg": "#E8ECFF", "line": "#20264F", "accent": "#5B63C9", "soft": "#FFD36A"},
    },
    {
        "slug": "candy-corn", "title": "Candy Corn Trail",
        "story_setup": "Denny found a Halloween candy bucket beside the path. Striped candy corn pieces are hiding around every turn.",
        "instruction": "Collect the candy corn and carry it to the candy bucket.",
        "fun_fact": "Candy corn was first made more than one hundred years ago.",
        "completion_message": "Denny collected the candy corn and filled the little Halloween bucket.",
        "task": "Collect the candy corn and carry it to the candy bucket.",
        "goal": "candy-bucket", "mode": "collect", "shape": "rect",
        "start": "bottom_left", "end": "top_right", "item": "candy-corn",
        "palette": {"bg": "#FFF9E8", "panel": "#FFFFFF", "maze_bg": "#FFF3C7", "line": "#4A2D45", "accent": "#ED7B32", "soft": "#FFD45C"},
    },
    {
        "slug": "moonlight", "title": "Moonlight Cat Maze",
        "story_setup": "A quiet trail curled across the Halloween sky like a shell. Denny spotted golden stars leading toward the moonlit hill.",
        "instruction": "Follow the wide path, collect the stars and reach the moonlit hill.",
        "fun_fact": "The Moon does not make its own light; it reflects light from the Sun.",
        "completion_message": "Denny followed the stars and reached the moonlit hill.",
        "task": "Follow the wide path, collect the stars and reach the moonlit hill.",
        "goal": "moon", "mode": "collect", "shape": "shell", "render_style": "corridor", "item_count_delta": -1,
        "start": "bottom_left", "end": "top_right", "item": "star",
        "palette": {"bg": "#F3F2FF", "panel": "#FFFFFF", "maze_bg": "#E9E7FF", "line": "#25264D", "accent": "#6564C8", "soft": "#FFD86B"},
    },
    {
        "slug": "ghost-bat-dodge", "title": "Ghost and Bat Dodge",
        "story_setup": "Denny found a candy bucket at the end of a moonlit path. A few silly ghosts and sleepy bats are floating between the turns.",
        "instruction": "Help Denny avoid the ghosts and bats and reach the candy bucket.",
        "fun_fact": "Bats are mammals, and baby bats drink milk from their mothers.",
        "completion_message": "Denny tiptoed past the ghosts and bats and found the candy bucket.",
        "task": "Avoid the ghosts and bats and reach the candy bucket.",
        "goal": "candy-bucket", "mode": "avoid", "shape": "rect",
        "start": "bottom_left", "end": "top_right", "item": "ghost",
        "avoid_items": ["ghost", "bat"],
        "hard_avoid_items": ["ghost", "bat", "ghost", "ghost"],
        "palette": {"bg": "#F6F3FF", "panel": "#FFFFFF", "maze_bg": "#ECE8F8", "line": "#29233F", "accent": "#7357A6", "soft": "#BAC6FF"},
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


def scale_path_to_box(
    source_width: float,
    source_height: float,
    x: float,
    y: float,
    width: float,
    height: float,
) -> str:
    scale = min(width / source_width, height / source_height)
    rendered_width = source_width * scale
    rendered_height = source_height * scale
    offset_x = x + (width - rendered_width) / 2
    offset_y = y + (height - rendered_height) / 2
    return f'translate({offset_x:.2f} {offset_y:.2f}) scale({scale:.4f})'


def maze_point_to_page(point: dict[str, float], source_width: float, source_height: float) -> dict[str, float]:
    scale = min(MAZE_WIDTH / source_width, MAZE_HEIGHT / source_height)
    width = source_width * scale
    height = source_height * scale
    offset_x = MAZE_X + (MAZE_WIDTH - width) / 2
    offset_y = MAZE_Y + (MAZE_HEIGHT - height) / 2
    return {
        "x": offset_x + point["x"] * scale,
        "y": offset_y + point["y"] * scale,
    }


def maze_point_to_box(
    point: dict[str, float],
    source_width: float,
    source_height: float,
    x: float,
    y: float,
    width: float,
    height: float,
) -> dict[str, float]:
    scale = min(width / source_width, height / source_height)
    rendered_width = source_width * scale
    rendered_height = source_height * scale
    offset_x = x + (width - rendered_width) / 2
    offset_y = y + (height - rendered_height) / 2
    return {
        "x": offset_x + point["x"] * scale,
        "y": offset_y + point["y"] * scale,
    }


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


def asset_href(kind: str, color: bool = False) -> str | None:
    cache_key = f"{'color' if color else 'bw'}:{kind}"
    if cache_key in _ASSET_DATA_CACHE:
        return _ASSET_DATA_CACHE[cache_key]

    asset_path = (ASSET_DIR if color else BW_ASSET_DIR) / f"{kind}.png"
    if not asset_path.exists():
        return None

    encoded = base64.b64encode(asset_path.read_bytes()).decode("ascii")
    href = f"data:image/png;base64,{encoded}"
    _ASSET_DATA_CACHE[cache_key] = href
    return href


def asset_svg(kind: str, x: float, y: float, size: float, palette: dict[str, str], badge: bool = True, color: bool = False) -> str:
    href = asset_href(kind, color)
    if href is None:
        return icon_svg(kind, x, y, size, palette)
    image = (
        f'<image href="{href}" x="{x - size / 2:.2f}" y="{y - size / 2:.2f}" '
        f'width="{size:.2f}" height="{size:.2f}" preserveAspectRatio="xMidYMid meet"/>'
    )
    if not badge:
        return image
    return f"""
  <g>
    {image}
  </g>"""


def denny_asset_svg(x: float, y: float, size: float, palette: dict[str, str], color: bool = False) -> str:
    if not ((ASSET_DIR if color else BW_ASSET_DIR) / "denny-black-cat.png").exists():
        return denny_svg(x, y, size / 72, True)
    return asset_svg("denny-black-cat", x, y, size, palette, color=color)


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

    if kind == "jack-o-lantern":
        return f"""
  <g transform="translate({x} {y})">
    <ellipse cx="0" cy="{size * 0.05}" rx="{size * 0.43}" ry="{size * 0.34}" fill="{accent}" stroke="{line}" stroke-width="{size * 0.035}"/>
    <path d="M 0 {-size * 0.27} L {size * 0.04} {-size * 0.48}" stroke="{line}" stroke-width="{size * 0.07}" stroke-linecap="round"/>
    <path d="M {-size * 0.25} {-size * 0.03} l {size * 0.13} {-size * 0.09} l {size * 0.08} {size * 0.16} Z M {size * 0.25} {-size * 0.03} l {-size * 0.13} {-size * 0.09} l {-size * 0.08} {size * 0.16} Z" fill="{line}"/>
    <path d="M {-size * 0.23} {size * 0.13} Q 0 {size * 0.33} {size * 0.23} {size * 0.13} Q 0 {size * 0.23} {-size * 0.23} {size * 0.13}" fill="{line}"/>
  </g>"""
    if kind == "candy-bucket":
        return f"""
  <g transform="translate({x} {y})">
    <path d="M {-size * 0.34} {-size * 0.12} L {size * 0.34} {-size * 0.12} L {size * 0.27} {size * 0.42} L {-size * 0.27} {size * 0.42} Z" fill="{accent}" stroke="{line}" stroke-width="{size * 0.04}"/>
    <path d="M {-size * 0.24} {-size * 0.1} Q 0 {-size * 0.55} {size * 0.24} {-size * 0.1}" fill="none" stroke="{line}" stroke-width="{size * 0.055}"/>
    <circle cx="{-size * 0.11}" cy="{size * 0.11}" r="{size * 0.035}" fill="{line}"/><circle cx="{size * 0.11}" cy="{size * 0.11}" r="{size * 0.035}" fill="{line}"/>
    <path d="M {-size * 0.1} {size * 0.23} Q 0 {size * 0.31} {size * 0.1} {size * 0.23}" fill="none" stroke="{line}" stroke-width="{size * 0.03}"/>
  </g>"""
    if kind == "spooky-house":
        return f"""
  <g transform="translate({x} {y})">
    <path d="M {-size * 0.44} {size * 0.02} L {-size * 0.12} {-size * 0.34} L 0 {-size * 0.2} L {size * 0.18} {-size * 0.48} L {size * 0.45} {size * 0.02} Z" fill="{line}"/>
    <path d="M {-size * 0.35} 0 H {size * 0.35} V {size * 0.45} H {-size * 0.35} Z" fill="{accent}" stroke="{line}" stroke-width="{size * 0.035}"/>
    <rect x="{-size * 0.09}" y="{size * 0.13}" width="{size * 0.18}" height="{size * 0.32}" fill="{soft}" stroke="{line}" stroke-width="{size * 0.025}"/>
    <rect x="{-size * 0.27}" y="{size * 0.1}" width="{size * 0.12}" height="{size * 0.13}" fill="{soft}"/>
    <rect x="{size * 0.15}" y="{size * 0.1}" width="{size * 0.12}" height="{size * 0.13}" fill="{soft}"/>
  </g>"""
    if kind == "candy-corn":
        return f"""
  <g transform="translate({x} {y})">
    <path d="M 0 {-size * 0.5} L {size * 0.36} {size * 0.4} Q 0 {size * 0.55} {-size * 0.36} {size * 0.4} Z" fill="{soft}" stroke="{line}" stroke-width="{size * 0.035}"/>
    <path d="M {-size * 0.19} {-size * 0.02} H {size * 0.19} L {size * 0.28} {size * 0.22} H {-size * 0.28} Z" fill="{accent}"/>
  </g>"""
    if kind == "star":
        points = "0,-0.5 0.12,-0.16 0.48,-0.15 0.2,0.07 0.3,0.42 0,0.22 -0.3,0.42 -0.2,0.07 -0.48,-0.15 -0.12,-0.16"
        return f'<polygon points="{points}" transform="translate({x} {y}) scale({size})" fill="{soft}" stroke="{line}" stroke-width="0.035"/>'
    if kind == "moon":
        return f"""
  <g transform="translate({x} {y})">
    <circle r="{size * 0.42}" fill="{soft}" stroke="{line}" stroke-width="{size * 0.035}"/>
    <circle cx="{size * 0.19}" cy="{-size * 0.12}" r="{size * 0.4}" fill="{palette['maze_bg']}"/>
  </g>"""
    if kind == "ghost":
        return f"""
  <g transform="translate({x} {y})">
    <path d="M {-size * 0.36} {size * 0.42} V {-size * 0.05} A {size * 0.36} {size * 0.4} 0 0 1 {size * 0.36} {-size * 0.05} V {size * 0.42} L {size * 0.18} {size * 0.28} L 0 {size * 0.42} L {-size * 0.18} {size * 0.28} Z" fill="{soft}" stroke="{line}" stroke-width="{size * 0.035}"/>
    <circle cx="{-size * 0.12}" cy="{-size * 0.06}" r="{size * 0.045}" fill="{line}"/><circle cx="{size * 0.12}" cy="{-size * 0.06}" r="{size * 0.045}" fill="{line}"/>
    <path d="M {-size * 0.09} {size * 0.1} Q 0 {size * 0.17} {size * 0.09} {size * 0.1}" fill="none" stroke="{line}" stroke-width="{size * 0.03}"/>
  </g>"""
    if kind == "bat":
        return f"""
  <g transform="translate({x} {y})">
    <path d="M 0 {-size * 0.08} C {-size * 0.13} {-size * 0.35}, {-size * 0.37} {-size * 0.34}, {-size * 0.5} {-size * 0.18} Q {-size * 0.35} {-size * 0.1} {-size * 0.28} {size * 0.16} Q {-size * 0.14} {size * 0.05} 0 {size * 0.28} Q {size * 0.14} {size * 0.05} {size * 0.28} {size * 0.16} Q {size * 0.35} {-size * 0.1} {size * 0.5} {-size * 0.18} C {size * 0.37} {-size * 0.34}, {size * 0.13} {-size * 0.35}, 0 {-size * 0.08} Z" fill="{accent}" stroke="{line}" stroke-width="{size * 0.035}"/>
    <path d="M {-size * 0.1} {-size * 0.12} L {-size * 0.04} {-size * 0.3} L {size * 0.02} {-size * 0.12}" fill="{line}"/>
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


def exit_svg(x: float, y: float, size: float) -> str:
    stroke = size * 0.075
    return f"""
  <g transform="translate({x:.2f} {y:.2f})">
    <path d="M {-size * 0.34:.2f} {size * 0.34:.2f} L {-size * 0.34:.2f} {-size * 0.34:.2f} L {size * 0.32:.2f} {-size * 0.34:.2f} L {size * 0.32:.2f} {size * 0.34:.2f}" fill="none" stroke="#000000" stroke-width="{stroke:.2f}" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M {-size * 0.12:.2f} 0 L {size * 0.42:.2f} 0 M {size * 0.22:.2f} {-size * 0.18:.2f} L {size * 0.42:.2f} 0 L {size * 0.22:.2f} {size * 0.18:.2f}" fill="none" stroke="#000000" stroke-width="{stroke:.2f}" stroke-linecap="round" stroke-linejoin="round"/>
  </g>"""


def hero_svg() -> str:
    palette = {"accent": "#F0782F", "soft": "#FFD66B", "line": "#28213D", "maze_bg": "#F1ECFF"}
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="700" viewBox="0 0 1200 700" role="img" aria-label="Denny dressed as a black cat with friendly Halloween decorations">
  <rect width="1200" height="700" fill="#F1ECFF"/>
  <circle cx="1010" cy="135" r="78" fill="#FFD66B"/>
  {icon_svg("bat", 160, 170, 74, palette)}
  {icon_svg("ghost", 1040, 390, 92, palette)}
  {icon_svg("jack-o-lantern", 185, 555, 108, palette)}
  {denny_asset_svg(600, 390, 410, palette, color=True)}
  <text x="600" y="76" text-anchor="middle" font-family="Arial, sans-serif" font-size="48" font-weight="700" fill="#28213D">Halloween Mazes with Denny</text>
  <text x="600" y="126" text-anchor="middle" font-family="Arial, sans-serif" font-size="26" fill="#5D5275">Friendly free printable mazes for calm seasonal play</text>
</svg>
"""


def hero_image_svg() -> str:
    return hero_svg()


def page_svg(theme: dict[str, Any], difficulty: str, maze: dict[str, Any], color: bool = False) -> str:
    diff = DIFFICULTIES[difficulty]
    palette = theme["palette"] if color else {
        "bg": "#FFFFFF",
        "panel": "#FFFFFF",
        "maze_bg": "#FFFFFF",
        "line": "#000000",
        "accent": "#000000",
        "soft": "#000000",
    }
    source_width = float(maze.get("canvas_width", 600))
    source_height = float(maze.get("canvas_height", 500))
    transform = scale_path(maze["svg_path"], source_width, source_height)
    if theme["slug"] == "moonlight":
        transform = scale_path_to_box(source_width, source_height, 28, 90, 154, 118)
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
    wall_stroke = diff["stroke"] * 2.1
    item_sizes = {"easy": 68, "medium": 44, "hard": 34}
    item_size = item_sizes[difficulty]
    if theme["slug"] == "moonlight" and difficulty == "easy":
        item_size = item_sizes["medium"]
    goal_size = 66
    if theme["slug"] in {"pumpkin-patch", "jack-o-lantern"}:
        goal_size = 86
    denny_size = item_sizes[difficulty]

    item_svgs = []
    for item in maze.get("items", []) if item_kind else []:
        item_svgs.append(
            f'<g transform="{item_transform}">{asset_svg(item_kind, item["x"], item["y"], item_size, palette, badge=False, color=color)}</g>'
        )
    avoid_kinds = (
        theme.get("hard_avoid_items", theme.get("avoid_items", [item_kind or "ghost"]))
        if difficulty == "hard"
        else theme.get("avoid_items", [item_kind or "ghost"])
    )
    avoid_item_size = {
        "easy": item_size,
        "medium": 55,
        "hard": 44,
    }[difficulty]
    for index, item in enumerate(maze.get("avoid_items", [])):
        avoid_kind = avoid_kinds[index % len(avoid_kinds)]
        item_svgs.append(
            f'<g transform="{item_transform}">{asset_svg(avoid_kind, item["x"], item["y"], avoid_item_size, palette, badge=False, color=color)}</g>'
        )
    is_corridor = str(maze.get("maze_type", "")).startswith("corridor")
    maze_path_svg = (
        f'<path d="{esc(maze["svg_path"])}" fill="none" stroke="{palette["line"]}" stroke-width="{float(maze.get("path_width", 25)) + 9:.2f}" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<path d="{esc(maze["svg_path"])}" fill="none" stroke="#FFFFFF" stroke-width="{float(maze.get("path_width", 25)):.2f}" stroke-linecap="round" stroke-linejoin="round"/>'
        if is_corridor
        else f'<path d="{esc(maze["svg_path"])}" fill="none" stroke="{palette["line"]}" stroke-width="{wall_stroke:.2f}" stroke-linecap="round" stroke-linejoin="round"/>'
    )
    goal_markup = (
        exit_svg(maze["end_point"]["x"], maze["end_point"]["y"], goal_size)
        if goal_kind == "exit"
        else asset_svg(goal_kind, maze["end_point"]["x"], maze["end_point"]["y"], goal_size, palette, color=color)
    )
    start_page = maze_point_to_page(maze["start_point"], source_width, source_height)
    denny_page_size = 18
    denny_x = min(MAZE_X + MAZE_WIDTH - 11, max(MAZE_X + 11, start_page["x"]))
    denny_y = min(MAZE_Y + MAZE_HEIGHT - 11, max(MAZE_Y + 11, start_page["y"]))
    denny_markup = denny_asset_svg(denny_x, denny_y, denny_page_size, palette, color=color)
    goal_group_markup = f"""
  <g transform="{transform}">
    {goal_markup}
  </g>"""
    if theme["slug"] == "moonlight":
        moon_denny_size = {"easy": 46, "medium": 44, "hard": 40}[difficulty]
        moon_goal_sizes = (
            {"easy": 54, "medium": 50, "hard": 46}
            if color
            else {"easy": 30, "medium": 28, "hard": 26}
        )
        moon_goal_size = moon_goal_sizes[difficulty]
        start_page = maze_point_to_box(maze["start_point"], source_width, source_height, 28, 90, 154, 118)
        end_page = maze_point_to_box(maze["end_point"], source_width, source_height, 28, 90, 154, 118)
        denny_markup = denny_asset_svg(
            max(MAZE_X + 20, start_page["x"] - 40),
            min(MAZE_Y + MAZE_HEIGHT - 24, start_page["y"] + 14),
            moon_denny_size,
            palette,
            color=color,
        )
        moon_x = min(MAZE_X + MAZE_WIDTH - 20, end_page["x"] + 28)
        moon_y = max(MAZE_Y + 18, end_page["y"] - 22)
        goal_group_markup = f"""
  <g aria-label="Moonlit hill destination">
    <path d="M {end_page['x']:.2f} {end_page['y']:.2f} L {moon_x:.2f} {moon_y:.2f}"
      fill="none" stroke="{palette['accent']}" stroke-width="0.9" stroke-dasharray="2.2 2.2"/>
    <circle cx="{end_page['x']:.2f}" cy="{end_page['y']:.2f}" r="3.2"
      fill="{palette['accent']}" stroke="#FFFFFF" stroke-width="1.1"/>
    {asset_svg(goal_kind, moon_x, moon_y, moon_goal_size, palette, color=color)}
  </g>"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="210mm" height="297mm" viewBox="0 0 210 297" role="img" aria-label="{esc(theme['title'])}, {esc(diff['label'])}">
  <rect width="210" height="297" fill="{palette['bg']}"/>
  <rect x="11" y="11" width="188" height="275" rx="6" fill="{palette['panel']}" stroke="{palette['line']}" stroke-width="0.8"/>
  <text x="105" y="27" text-anchor="middle" font-family="Arial, sans-serif" font-size="11.5" font-weight="700" fill="{palette['line']}">{esc(theme['title'])}</text>
  <text x="105" y="39" text-anchor="middle" font-family="Arial, sans-serif" font-size="5.5" font-weight="700" fill="{palette['accent']}">{esc(diff['label'])}</text>
{text_lines(story_lines, 105, 51, 4.5, palette['line'])}
{text_lines(instruction_lines, 105, 65, 4.9, palette['accent'], '700')}

  <rect x="{MAZE_X - 5}" y="{MAZE_Y - 5}" width="{MAZE_WIDTH + 10}" height="{MAZE_HEIGHT + 10}" rx="5" fill="{palette['maze_bg']}" stroke="{palette['line']}" stroke-width="0.9"/>
  <g transform="{transform}">
    {maze_path_svg}
  </g>
  {''.join(item_svgs)}
  {denny_markup}
  {goal_group_markup}

  <rect x="29" y="{fact_box_y:.1f}" width="152" height="{fact_box_height:.1f}" rx="4" fill="#FFFFFF" stroke="{palette['line']}" stroke-width="0.8"/>
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

    with tempfile.TemporaryDirectory() as profile_dir:
        try:
            process = subprocess.Popen(
                [
                    str(chrome),
                    "--headless=new",
                    "--disable-gpu",
                    "--disable-extensions",
                    "--disable-background-networking",
                    "--disable-sync",
                    "--disable-dev-shm-usage",
                    "--no-sandbox",
                    "--no-first-run",
                    "--no-default-browser-check",
                    f"--user-data-dir={profile_dir}",
                    "--print-to-pdf-no-header",
                    f"--print-to-pdf={pdf_path}",
                    wrapper_path.as_uri(),
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline:
                if pdf_path.exists() and pdf_path.stat().st_size > 0:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
                    return
                if process.poll() is not None:
                    break
                time.sleep(0.25)
            returncode = process.poll()
            if returncode is None:
                process.kill()
                process.wait(timeout=5)
                raise RuntimeError(f"Timed out generating PDF for {svg_path.name}")
            raise RuntimeError(f"Chrome failed generating PDF for {svg_path.name} with exit code {returncode}")
        finally:
            wrapper_path.unlink(missing_ok=True)


def generate() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    svg_dir = OUTPUT_DIR / "svg"
    pdf_dir = OUTPUT_DIR / "pdf"
    json_dir = OUTPUT_DIR / "json"
    color_svg_dir = OUTPUT_DIR / "color" / "svg"
    color_pdf_dir = OUTPUT_DIR / "color" / "pdf"
    svg_dir.mkdir(exist_ok=True)
    pdf_dir.mkdir(exist_ok=True)
    json_dir.mkdir(exist_ok=True)
    color_svg_dir.mkdir(parents=True, exist_ok=True)
    color_pdf_dir.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(exist_ok=True)
    BW_ASSET_DIR.mkdir(exist_ok=True)
    for stale in [*svg_dir.glob("*.svg"), *pdf_dir.glob("*.pdf"), *json_dir.glob("*.json"), *color_svg_dir.glob("*.svg"), *color_pdf_dir.glob("*.pdf")]:
        stale.unlink()

    maze_generator = FullMazeGenerator()
    manifest: dict[str, Any] = {
        "title": "Halloween Mazes with Denny",
        "website": WEBSITE,
        "format": "Color and black-and-white A4 PDF printables with SVG previews",
        "hero": "hero-denny-black-cat.svg",
        "hero_image": "assets/denny-black-cat.png",
        "total": 0,
        "mazes": [],
    }

    (OUTPUT_DIR / "hero-denny-black-cat.svg").write_text(hero_svg(), encoding="utf-8")

    for theme in THEMES:
        for difficulty, diff in DIFFICULTIES.items():
            random.seed(f"halloween-printable-{theme['slug']}-{difficulty}")
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
                if theme["slug"] == "ghost-bat-dodge" and difficulty == "hard":
                    item_count += 1
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
            color_svg_path = color_svg_dir / f"{slug}.svg"
            color_pdf_path = color_pdf_dir / f"{slug}.pdf"

            svg_path.write_text(page_svg(theme, difficulty, maze, color=False), encoding="utf-8")
            svg_to_pdf(svg_path, pdf_path)
            color_svg_path.write_text(page_svg(theme, difficulty, maze, color=True), encoding="utf-8")
            svg_to_pdf(color_svg_path, color_pdf_path)
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
                "color_svg": f"color/svg/{slug}.svg",
                "color_pdf": f"color/pdf/{slug}.pdf",
            })

    manifest["total"] = len(manifest["mazes"])
    for difficulty, diff in DIFFICULTIES.items():
        zip_path = OUTPUT_DIR / f"halloween-mazes-{difficulty}.zip"
        color_zip_path = OUTPUT_DIR / f"halloween-mazes-color-{difficulty}.zip"
        with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for theme in THEMES:
                slug = f"{theme['slug']}-{difficulty}"
                archive.write(pdf_dir / f"{slug}.pdf", arcname=f"{slug}.pdf")
        with zipfile.ZipFile(color_zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for theme in THEMES:
                slug = f"{theme['slug']}-{difficulty}"
                archive.write(color_pdf_dir / f"{slug}.pdf", arcname=f"{slug}.pdf")
        manifest.setdefault("packs", []).append({
            "label": diff["label"],
            "difficulty": difficulty,
            "zip": f"halloween-mazes-{difficulty}.zip",
            "color_zip": f"halloween-mazes-color-{difficulty}.zip",
        })

    (OUTPUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    (OUTPUT_DIR / "README.md").write_text(
        "# Halloween Mazes with Denny\n\n"
        "Generated A4 PDF printables for Harmless Apps website content.\n\n"
        "- 6 friendly Halloween themes\n"
        "- 3 difficulty levels per theme\n"
        "- Color and printer-friendly black-and-white versions\n"
        "- Individual worksheets are PDFs, with SVG files kept for web previews\n"
        "- Includes plain, collect, shaped and avoid maze variants\n"
        "- Footer includes `www.harmlessapp.com`\n"
        "- `json/` files keep maze metadata and solution paths for future web pages\n",
        encoding="utf-8",
    )

    print(f"Generated {manifest['total']} printable mazes in {OUTPUT_DIR}")


if __name__ == "__main__":
    generate()
