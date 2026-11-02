#!/usr/bin/env python3
"""Generate original uppercase/lowercase print-handwriting paths and a review sheet.

The construction uses straight pen movements, cubic curves, and elliptical arcs,
not font outlines or the old alphabet cue table. Each pen() call is a pen lift.
Coordinates share the app's 109-square writing box: cap/ascender 21, x-height 45,
baseline 87, descender 104. Simple single-storey a and g are used for beginners.
"""

import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/latin-strokes.json"
PREVIEW = ROOT / "content/tracing/latin-preview.svg"
COLORS = ["#147a5c", "#126e9e", "#bf522e", "#8042a8"]


def point(x, y):
    return {"x": round(x, 6), "y": round(y, 6)}


def L(x, y):
    return ("L", x, y)


def C(*values):
    return ("C", *values)


def pen(start, label, *commands):
    current = start
    curves = []
    for command in commands:
        if command[0] == "L":
            end = command[1:]
            c1 = tuple(a + (b - a) / 3 for a, b in zip(current, end))
            c2 = tuple(a + (b - a) * 2 / 3 for a, b in zip(current, end))
        else:
            c1, c2, end = command[1:3], command[3:5], command[5:7]
        curves.append({"control1": point(*c1), "control2": point(*c2), "end": point(*end)})
        current = end
    return {"start": point(*start), "curves": curves, "numberPosition": point(*label)}


def line(start, end, label):
    return pen(start, label, L(*end))


def oval(cx, cy, rx, ry, label, start_angle=-90):
    """Four quarter-circle Beziers, counterclockwise from the numbered start."""
    angle = math.radians(start_angle)
    start = (cx + rx * math.cos(angle), cy + ry * math.sin(angle))
    commands = []
    for _ in range(4):
        end_angle = angle - math.pi / 2
        k = 4 / 3 * math.tan((end_angle - angle) / 4)
        commands.append(C(
            cx + rx * (math.cos(angle) - k * math.sin(angle)),
            cy + ry * (math.sin(angle) + k * math.cos(angle)),
            cx + rx * (math.cos(end_angle) + k * math.sin(end_angle)),
            cy + ry * (math.sin(end_angle) - k * math.cos(end_angle)),
            cx + rx * math.cos(end_angle), cy + ry * math.sin(end_angle),
        ))
        angle = end_angle
    return pen(start, label, *commands)


def generate():
    glyphs = {
        "A": [line((55, 21), (28, 87), (44, 15)), line((55, 21), (82, 87), (66, 15)), line((39, 61), (71, 61), (29, 57))],
        "B": [line((32, 21), (32, 87), (21, 20)),
              pen((32, 21), (43, 12), C(88, 15, 88, 56, 32, 53)),
              pen((32, 53), (43, 45), C(95, 47, 95, 91, 32, 87))],
        "C": [pen((81, 32), (89, 23), C(66, 12, 28, 17, 27, 53), C(26, 88, 63, 98, 81, 78))],
        "D": [line((32, 21), (32, 87), (21, 20)), pen((32, 21), (43, 12), C(100, 15, 100, 93, 32, 87))],
        "E": [line((33, 21), (33, 87), (22, 20)), line((33, 21), (79, 21), (44, 12)),
              line((33, 53), (70, 53), (22, 49)), line((33, 87), (79, 87), (22, 83))],
        "F": [line((33, 21), (33, 87), (22, 20)), line((33, 21), (79, 21), (44, 12)), line((33, 53), (70, 53), (22, 49))],
        "G": [pen((80, 32), (89, 23), C(64, 11, 27, 18, 26, 53), C(25, 88, 63, 98, 83, 78)),
              pen((57, 57), (48, 51), L(83, 57), L(83, 78))],
        "H": [line((30, 21), (30, 87), (19, 20)), line((80, 21), (80, 87), (90, 20)), line((30, 54), (80, 54), (19, 51))],
        "I": [line((32, 21), (78, 21), (22, 17)), line((55, 21), (55, 87), (65, 32)), line((32, 87), (78, 87), (22, 83))],
        "J": [pen((76, 21), (87, 20), L(76, 69), C(76, 94, 38, 96, 30, 76))],
        "K": [line((31, 21), (31, 87), (20, 20)), line((80, 21), (32, 58), (89, 17)), line((48, 46), (82, 87), (48, 35))],
        "L": [line((33, 21), (33, 87), (22, 20)), line((33, 87), (80, 87), (22, 83))],
        "M": [line((25, 21), (25, 87), (14, 20)), line((25, 21), (55, 65), (36, 15)),
              line((55, 65), (85, 21), (55, 76)), line((85, 21), (85, 87), (95, 20))],
        "N": [line((29, 21), (29, 87), (18, 20)), line((29, 21), (81, 87), (40, 15)), line((81, 21), (81, 87), (91, 20))],
        "O": [oval(55, 54, 28, 34, (46, 12))],
        "P": [line((33, 21), (33, 87), (22, 20)), pen((33, 21), (44, 12), C(94, 14, 94, 64, 33, 57))],
        "Q": [oval(55, 54, 28, 34, (46, 12)), line((64, 72), (89, 97), (74, 69))],
        "R": [line((33, 21), (33, 87), (22, 20)), pen((33, 21), (44, 12), C(94, 14, 94, 64, 33, 57)),
              line((55, 58), (83, 87), (55, 69))],
        "S": [pen((79, 30), (87, 21), C(57, 10, 22, 22, 31, 43), C(39, 62, 76, 47, 80, 69), C(84, 93, 44, 96, 28, 78))],
        "T": [line((25, 21), (85, 21), (15, 17)), line((55, 21), (55, 87), (66, 32))],
        "U": [pen((29, 21), (18, 20), L(29, 64), C(29, 98, 81, 98, 81, 64), L(81, 21))],
        "V": [pen((27, 21), (16, 20), L(55, 87), L(83, 21))],
        "W": [pen((20, 21), (10, 20), L(36, 87), L(55, 39), L(74, 87), L(90, 21))],
        "X": [line((28, 21), (82, 87), (17, 20)), line((82, 21), (28, 87), (92, 20))],
        "Y": [line((27, 21), (55, 54), (16, 20)), line((83, 21), (55, 54), (93, 20)), line((55, 54), (55, 87), (44, 62))],
        "Z": [pen((27, 21), (16, 17), L(83, 21), L(27, 87), L(83, 87))],
        "a": [oval(54, 66, 23, 21, (87, 60), 0), line((77, 45), (77, 87), (78, 34))],
        "b": [line((32, 21), (32, 87), (21, 20)), pen((32, 58), (21, 55), C(47, 34, 81, 44, 81, 65), C(81, 89, 48, 96, 32, 78))],
        "c": [pen((77, 51), (87, 44), C(59, 36, 31, 45, 31, 66), C(31, 89, 60, 96, 77, 81))],
        "d": [oval(54, 66, 23, 21, (87, 60), 0), line((77, 21), (77, 87), (88, 20))],
        "e": [pen((31, 64), (21, 58), L(79, 64), C(79, 37, 32, 37, 31, 65), C(30, 88, 59, 97, 78, 80))],
        "f": [pen((76, 26), (85, 19), C(62, 13, 45, 23, 45, 38), L(45, 87)), line((28, 49), (70, 49), (18, 45))],
        "g": [oval(54, 66, 23, 21, (87, 60), 0), pen((77, 45), (78, 34), L(77, 89), C(77, 107, 48, 108, 37, 98))],
        "h": [line((32, 21), (32, 87), (21, 20)), pen((32, 65), (21, 62), C(40, 37, 77, 39, 77, 63), L(77, 87))],
        "i": [line((55, 45), (55, 87), (44, 44)), line((55, 28), (55, 30), (65, 25))],
        "j": [pen((62, 45), (73, 44), L(62, 88), C(62, 106, 43, 108, 35, 98)), line((62, 28), (62, 30), (72, 25))],
        "k": [line((33, 21), (33, 87), (22, 20)), line((77, 45), (33, 69), (87, 40)), line((51, 59), (80, 87), (52, 49))],
        "l": [line((55, 21), (55, 87), (44, 20))],
        "m": [line((25, 45), (25, 87), (14, 40)), pen((25, 63), (14, 60), C(30, 39, 55, 39, 55, 62), L(55, 87)),
              pen((55, 63), (64, 36), C(61, 39, 85, 39, 85, 62), L(85, 87))],
        "n": [line((32, 45), (32, 87), (21, 40)), pen((32, 64), (21, 61), C(40, 38, 78, 39, 78, 63), L(78, 87))],
        "o": [oval(55, 66, 24, 21, (88, 60), 0)],
        "p": [line((32, 45), (32, 104), (21, 40)), pen((32, 53), (42, 36), C(49, 35, 81, 44, 81, 65), C(81, 87, 49, 95, 32, 78))],
        "q": [oval(54, 66, 23, 21, (87, 60), 0), line((77, 45), (77, 104), (78, 34))],
        "r": [line((36, 45), (36, 87), (25, 40)), pen((36, 63), (25, 60), C(43, 40, 65, 40, 75, 50))],
        "s": [pen((74, 50), (84, 42), C(56, 36, 28, 44, 36, 58), C(44, 72, 77, 59, 77, 76), C(77, 92, 48, 94, 33, 81))],
        "t": [pen((51, 28), (40, 25), L(51, 77), C(51, 92, 67, 91, 75, 83)), line((29, 49), (76, 49), (19, 45))],
        "u": [pen((32, 45), (21, 40), L(32, 72), C(32, 96, 68, 94, 77, 72)), line((77, 45), (77, 87), (88, 40))],
        "v": [pen((31, 45), (20, 40), L(55, 87), L(79, 45))],
        "w": [pen((21, 45), (10, 40), L(37, 87), L(55, 56), L(73, 87), L(89, 45))],
        "x": [line((32, 45), (78, 87), (21, 40)), line((78, 45), (32, 87), (89, 40))],
        "y": [line((31, 45), (55, 82), (20, 40)), line((79, 45), (46, 104), (90, 40))],
        "z": [pen((31, 45), (20, 40), L(79, 45), L(31, 87), L(79, 87))],
    }
    assert set(glyphs) == set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    return {
        "source": "Original programmatic print-handwriting construction: scripts/generate_latin_tracing.py",
        "metrics": {"viewBox": 109, "capHeight": 21, "xHeight": 45, "baseline": 87, "descender": 104},
        "glyphs": glyphs,
    }


def svg_path(stroke):
    start = stroke["start"]
    parts = [f'M{start["x"]},{start["y"]}']
    for curve in stroke["curves"]:
        parts.append("C" + " ".join(f'{curve[key]["x"]},{curve[key]["y"]}' for key in ["control1", "control2", "end"]))
    return " ".join(parts)


def preview(data):
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1400" viewBox="0 0 1400 1400">',
             '<rect width="1400" height="1400" fill="#faf5e3"/>']
    for index, capital in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):
        x, y = (index % 7) * 200, (index // 7) * 260
        parts.append(f'<text x="{x + 12}" y="{y + 20}" font-family="sans-serif" font-size="15">{capital}{capital.lower()}</text>')
        for case_index, character in enumerate([capital, capital.lower()]):
            for row in range(2):
                parts.append(f'<g transform="translate({x + case_index * 98},{y + 25 + row * 114}) scale(.9)">')
                for stroke_index, stroke in enumerate(data["glyphs"][character]):
                    d = svg_path(stroke)
                    parts.append(f'<path d="{d}" fill="none" stroke="#dddcd7" stroke-width="7.3" stroke-linecap="round" stroke-linejoin="round"/>')
                    if row == 0:
                        color = COLORS[stroke_index % len(COLORS)]
                        parts.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"/>')
                    if row == 0:
                        parts.append(f'<path d="{d}" fill="none" stroke="#ee7665" stroke-width="3.1" stroke-dasharray="0 5.7" stroke-linecap="round"/>')
                if row == 0:
                    for stroke_index, stroke in enumerate(data["glyphs"][character]):
                        p = stroke["numberPosition"]
                        color = COLORS[stroke_index % len(COLORS)]
                        parts.append(f'<circle cx="{p["x"]}" cy="{p["y"]}" r="4.7" fill="{color}"/>')
                        parts.append(f'<text x="{p["x"]}" y="{p["y"] + 2}" text-anchor="middle" font-family="sans-serif" font-weight="bold" font-size="6" fill="white">{stroke_index + 1}</text>')
                parts.append('</g>')
    parts.append('</svg>')
    return "\n".join(parts) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = generate()
    sheet = preview(data)
    if args.check:
        assert json.loads(OUTPUT.read_text()) == data, "Latin stroke resource needs regeneration"
        assert PREVIEW.read_text() == sheet, "Latin review sheet needs regeneration"
        print("Verified all 52 generated Latin glyphs and the review sheet.")
    else:
        OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        PREVIEW.parent.mkdir(parents=True, exist_ok=True)
        PREVIEW.write_text(sheet)
        print("Generated all 52 Latin glyphs and content/tracing/latin-preview.svg.")


if __name__ == "__main__":
    main()
