#!/usr/bin/env python3
"""Convert the pinned KanjiVG kana SVGs to exact, ordered cubic tracing paths.

Download the source SVGs and COPYING from REVISION into a local directory, then:
    python3 scripts/import_hiragana_tracing.py /path/to/kanjivg/kanji

Only local files are read. No runtime SVG parser or network connection is needed.
"""

import argparse
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

REVISION = "70a0b7ae0c18ceb5cb358274b029cce0234a43bc"
CHARACTERS = "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん"
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/hiragana-strokes.json"
SVG_NS = {"svg": "http://www.w3.org/2000/svg"}
TOKEN = re.compile(r"[MmCcSs]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?")


def point(x, y):
    return {"x": round(x, 6), "y": round(y, 6)}


def parse_path(data):
    """Expand relative curves and reflected S controls without sampling curves."""
    tokens = TOKEN.findall(data)
    remainder = TOKEN.sub("", data)
    if remainder.strip(" ,\t\r\n"):
        raise ValueError(f"Unsupported SVG command: {data}")
    index = 0
    current = (0, 0)
    previous_control = None
    command = None
    start = None
    curves = []
    while index < len(tokens):
        if tokens[index] in "MmCcSs":
            command = tokens[index]
            index += 1
        count = {"M": 2, "C": 6, "S": 4}[command.upper()]
        values = list(map(float, tokens[index:index + count]))
        if len(values) != count:
            raise ValueError("Incomplete SVG curve")
        index += count
        pairs = list(zip(values[::2], values[1::2]))
        if command.islower():
            pairs = [(x + current[0], y + current[1]) for x, y in pairs]
        if command.upper() == "M":
            if start is not None:
                raise ValueError("A tracing stroke must have exactly one move")
            current = pairs[0]
            start = point(*current)
            previous_control = None
            command = None
            continue
        if command.upper() == "S":
            reflected = current if previous_control is None else (
                2 * current[0] - previous_control[0], 2 * current[1] - previous_control[1]
            )
            pairs.insert(0, reflected)
        control1, control2, end = pairs
        curves.append({"control1": point(*control1), "control2": point(*control2), "end": point(*end)})
        current = end
        previous_control = control2
    if start is None or not curves:
        raise ValueError("Empty tracing stroke")
    return start, curves


def convert(source):
    glyphs = {}
    for character in CHARACTERS:
        codepoint = f"{ord(character):05x}"
        root = ET.parse(source / f"{codepoint}.svg").getroot()
        if root.attrib["viewBox"] != "0 0 109 109":
            raise ValueError("Unexpected KanjiVG coordinate system")
        paths = root.findall(".//svg:path", SVG_NS)
        numbers = root.findall(".//svg:text", SVG_NS)
        if len(paths) != len(numbers):
            raise ValueError(f"Missing stroke numbers for {character}")
        strokes = []
        for order, (path, number) in enumerate(zip(paths, numbers), 1):
            if not path.attrib["id"].endswith(f"-s{order}") or number.text != str(order):
                raise ValueError(f"Incorrect stroke order for {character}")
            transform = number.attrib["transform"]
            matrix = list(map(float, re.findall(r"[-+]?(?:\d*\.\d+|\d+)", transform)))
            if matrix[:4] != [1, 0, 0, 1] or len(matrix) != 6:
                raise ValueError(f"Unsupported number transform: {transform}")
            start, curves = parse_path(path.attrib["d"])
            strokes.append({
                "start": start, "curves": curves,
                # SVG labels use a baseline; badges use their visual centre.
                "numberPosition": point(matrix[4] + 3, matrix[5] - 3),
            })
        glyphs[character] = strokes
    return {
        "source": f"https://github.com/KanjiVG/kanjivg/tree/{REVISION}/kanji",
        "copyright": "Copyright (C) 2009/2010/2011 Ulrich Apel. KanjiVG: https://kanjivg.tagaini.net/",
        "license": "CC BY-SA 3.0: https://creativecommons.org/licenses/by-sa/3.0/",
        "changes": "Expanded relative and smooth SVG curves to absolute cubic controls; adjusted label baselines to badge centres. Stroke order and geometry preserved.",
        "glyphs": glyphs,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--check", action="store_true", help="Verify the bundled data without changing it")
    args = parser.parse_args()
    data = convert(args.source)
    if args.check:
        if json.loads(OUTPUT.read_text()) != data:
            raise SystemExit("Bundled hiragana differs from the pinned source")
        print("Verified all 46 hiragana: exact cubic geometry, stroke order, and number positions.")
    else:
        OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        print(f"Wrote {len(data['glyphs'])} hiragana to {OUTPUT}")


if __name__ == "__main__":
    main()
