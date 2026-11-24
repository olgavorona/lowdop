#!/usr/bin/env python3
"""Generate original beginner Naskh-style isolated Arabic pen paths.

Paths are original centreline geometry, not font outlines or copied diagrams.
The 109-square writing box, cubic schema and rendering match Latin and kana.
Body strokes precede dots; paired dots go right to left, three dots finish at
the top. Alif/ascenders descend; bowls start at the right and finish at the left.
Teaching references and the scope of the isolated forms are in docs/arabic-tracing.md.
"""

import argparse
import json
from pathlib import Path

from generate_latin_tracing import C, L, COLORS, line, pen, svg_path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/arabic-strokes.json"
PREVIEW = ROOT / "content/tracing/arabic-preview.svg"
ALPHABET = "ابتثجحخدذرزسشصضطظعغفقكلمنهوي"


def dot(x, y, label):
    # A short pen tap remains visible with round caps and the shared dot renderer.
    return line((x, y), (x, y + .8), label)


def generate():
    bowl = pen((88, 49), (99, 44), C(94, 72, 78, 79, 52, 79), C(27, 79, 17, 72, 22, 55))
    jeem = pen((31, 34), (23, 26), C(46, 26, 63, 34, 79, 40),
               C(53, 46, 26, 54, 26, 72), C(24, 94, 57, 101, 81, 86))
    dal = pen((57, 38), (48, 30), C(65, 43, 78, 58, 78, 66), C(68, 76, 46, 77, 34, 73))
    ra = pen((73, 48), (84, 43), C(79, 67, 68, 87, 37, 93))
    seen = pen((94, 45), (101, 34), C(97, 69, 80, 70, 81, 49),
               C(84, 71, 66, 72, 67, 51), C(70, 68, 60, 74, 54, 68),
               C(59, 100, 17, 103, 18, 73), C(18, 67, 20, 62, 22, 58))
    sad = pen((51, 65), (39, 58), C(61, 48, 77, 38, 88, 45),
              C(104, 60, 83, 73, 51, 65), C(55, 98, 17, 102, 18, 72), L(21, 58))
    tah = pen((37, 73), (26, 80), C(48, 49, 69, 40, 81, 47), C(100, 66, 77, 77, 37, 73))
    ayn = pen((73, 36), (82, 27), C(60, 24, 40, 33, 42, 45), C(44, 55, 60, 53, 73, 48),
              C(48, 53, 26, 66, 29, 82), C(31, 99, 63, 102, 82, 89))
    fa = pen((74, 61), (62, 51), C(52, 46, 65, 30, 77, 38), C(91, 45, 85, 63, 74, 61),
             C(93, 75, 65, 83, 42, 80), C(23, 79, 18, 71, 22, 58))
    qaf = pen((74, 59), (60, 49), C(54, 44, 66, 30, 78, 38), C(91, 46, 84, 63, 74, 59),
              C(88, 94, 57, 102, 35, 92), C(19, 85, 19, 68, 26, 57))
    glyphs = {
        "ا": [line((59, 19), (59, 80), (72, 17))],
        "ب": [bowl, dot(53, 94, (68, 96))],
        "ت": [bowl, dot(62, 37, (72, 28)), dot(46, 37, (36, 28))],
        "ث": [bowl, dot(62, 38, (77, 36)), dot(46, 38, (31, 36)), dot(54, 24, (54, 12))],
        "ج": [jeem, dot(53, 72, (67, 74))],
        "ح": [jeem],
        "خ": [jeem, dot(55, 19, (69, 15))],
        "د": [dal],
        "ذ": [dal, dot(58, 23, (72, 20))],
        "ر": [ra],
        "ز": [ra, dot(67, 30, (81, 25))],
        "س": [seen],
        "ش": [seen, dot(82, 30, (96, 24)), dot(66, 30, (52, 24)), dot(74, 17, (74, 7))],
        "ص": [sad],
        "ض": [sad, dot(74, 29, (87, 23))],
        "ط": [tah, line((43, 20), (43, 63), (30, 18))],
        "ظ": [tah, line((43, 20), (43, 63), (30, 18)), dot(71, 31, (85, 25))],
        "ع": [ayn],
        "غ": [ayn, dot(58, 17, (44, 10))],
        "ف": [fa, dot(73, 22, (87, 16))],
        "ق": [qaf, dot(81, 22, (96, 17)), dot(65, 22, (51, 17))],
        "ك": [pen((82, 20), (95, 18), L(82, 68), C(83, 83, 39, 85, 25, 77), C(20, 74, 20, 68, 22, 62)),
              pen((57, 39), (68, 33), L(45, 49), C(66, 48, 62, 62, 43, 61))],
        "ل": [pen((75, 19), (88, 16), L(75, 70), C(77, 101, 27, 102, 27, 76), L(29, 64))],
        "م": [pen((56, 56), (43, 43), C(62, 29, 86, 39, 79, 55), C(75, 67, 58, 62, 56, 56),
                  C(34, 58, 46, 81, 45, 99))],
        "ن": [pen((81, 48), (94, 42), C(91, 98, 23, 104, 26, 62), L(28, 53)), dot(55, 43, (55, 30))],
        "ه": [pen((62, 38), (74, 29), C(77, 45, 87, 60, 79, 73), C(67, 90, 38, 88, 32, 73),
                  C(26, 57, 45, 45, 62, 38))],
        "و": [pen((73, 62), (60, 51), C(52, 47, 64, 29, 77, 38), C(92, 50, 83, 66, 73, 62),
                  C(81, 82, 60, 97, 35, 95))],
        "ي": [pen((82, 44), (94, 37), C(67, 33, 52, 41, 54, 53), C(55, 61, 76, 59, 75, 72),
                  C(72, 91, 22, 92, 23, 68), L(25, 58)),
              dot(59, 99, (73, 101)), dot(43, 99, (29, 101))],
    }
    assert set(glyphs) == set(ALPHABET) and len(glyphs) == 28
    return {"coordinateSpace": 109, "style": "Original beginner Naskh-style isolated letter paths", "glyphs": glyphs}


def preview(data):
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="960" viewBox="0 0 1400 960">',
             '<rect width="1400" height="960" fill="#faf5e3"/>',
             '<text x="28" y="30" font-family="sans-serif" font-size="20">Arabic isolated letters · numbered pen strokes · body before dots · read rows from right to left</text>']
    for index, character in enumerate(ALPHABET):
        x, y = (6 - index % 7) * 200, 50 + (index // 7) * 225
        parts.append(f'<text x="{x + 100}" y="{y + 22}" text-anchor="middle" font-size="24">{character}</text>')
        for row in range(2):
            parts.append(f'<g transform="translate({x + 46},{y + 28 + row * 96}) scale(.85)">')
            for i, stroke in enumerate(data["glyphs"][character]):
                d = svg_path(stroke)
                color = COLORS[i % len(COLORS)] if row == 0 else "#d9d7d0"
                parts.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>')
            if row == 0:
                for i, stroke in enumerate(data["glyphs"][character]):
                    p = stroke["numberPosition"]
                    parts.append(f'<circle cx="{p["x"]}" cy="{p["y"]}" r="5" fill="{COLORS[i % len(COLORS)]}"/>')
                    parts.append(f'<text x="{p["x"]}" y="{p["y"] + 2}" text-anchor="middle" font-family="sans-serif" font-size="7" fill="white">{i + 1}</text>')
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
        assert json.loads(OUTPUT.read_text()) == data, "Arabic paths need regeneration"
        assert PREVIEW.read_text() == sheet, "Arabic review sheet needs regeneration"
        print("Verified all 28 Arabic letters and the review sheet.")
    else:
        OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        PREVIEW.parent.mkdir(parents=True, exist_ok=True)
        PREVIEW.write_text(sheet)
        print("Generated all 28 Arabic letters and content/tracing/arabic-preview.svg.")


if __name__ == "__main__":
    main()
