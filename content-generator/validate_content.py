#!/usr/bin/env python3
"""Validation script for Low Dopamine Labyrinth JSON content."""

import json
import os
import re
import sys

LABYRINTHS_DIR = os.path.join(os.path.dirname(__file__), "output", "labyrinths")

REQUIRED_TOP_FIELDS = [
    "id", "age_range", "difficulty", "theme", "title",
    "story_setup", "instruction", "tts_instruction",
    "character_start", "character_end",
    "educational_question", "fun_fact", "completion_message",
    "path_data", "visual_theme",
]

REQUIRED_CHARACTER_FIELDS = ["type", "description", "position"]

REQUIRED_PATH_DATA_FIELDS = [
    "svg_path", "solution_path", "width", "complexity", "maze_type",
    "start_point", "end_point", "segments", "canvas_width", "canvas_height",
]

REQUIRED_POINT_FIELDS = ["x", "y"]

HEX_COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")


def load_json(filepath):
    with open(filepath, "r") as f:
        return json.load(f)


def check_fields(data, required, context):
    errors = []
    for field in required:
        if field not in data:
            errors.append(f"{context}: missing required field '{field}'")
    return errors


def parse_solution_steps(solution_path):
    """Count the number of L (lineTo) commands in solution_path SVG string."""
    if not solution_path:
        return 0
    # Each "L x y" is a step; the initial "M x y" is the start
    parts = re.findall(r"[ML]\s+[\d.]+\s+[\d.]+", solution_path)
    return len(parts)


def extract_svg_endpoint(solution_path, which="start"):
    """Extract start or end point from solution_path SVG string."""
    if not solution_path:
        return None
    parts = re.findall(r"[ML]\s+([\d.]+)\s+([\d.]+)", solution_path)
    if not parts:
        return None
    idx = 0 if which == "start" else -1
    return (float(parts[idx][0]), float(parts[idx][1]))


def validate_labyrinth(filepath):
    errors = []
    warnings = []
    filename = os.path.basename(filepath)

    try:
        data = load_json(filepath)
    except json.JSONDecodeError as e:
        return [f"{filename}: invalid JSON - {e}"], []

    # 1. Schema validation - top-level fields
    errors.extend(check_fields(data, REQUIRED_TOP_FIELDS, filename))

    # Character fields
    for char_key in ["character_start", "character_end"]:
        if char_key in data:
            errors.extend(check_fields(data[char_key], REQUIRED_CHARACTER_FIELDS, f"{filename}.{char_key}"))

    # Path data fields
    pd = data.get("path_data", {})
    errors.extend(check_fields(pd, REQUIRED_PATH_DATA_FIELDS, f"{filename}.path_data"))

    for pt_key in ["start_point", "end_point"]:
        if pt_key in pd:
            errors.extend(check_fields(pd[pt_key], REQUIRED_POINT_FIELDS, f"{filename}.path_data.{pt_key}"))

    # Visual theme
    vt = data.get("visual_theme", {})
    if "background_color" not in vt:
        errors.append(f"{filename}.visual_theme: missing 'background_color'")
    if "decorative_elements" not in vt:
        errors.append(f"{filename}.visual_theme: missing 'decorative_elements'")

    # 2. Maze solvability - for grid/shaped mazes, solution_path must be non-empty
    maze_type = pd.get("maze_type", "")
    solution_path = pd.get("solution_path", "")
    difficulty = data.get("difficulty", "")

    if maze_type != "organic":
        if not solution_path or not solution_path.strip():
            errors.append(f"{filename}: non-organic maze (type={maze_type}) has empty solution_path")
        else:
            # Check solution starts at start_point and ends at end_point
            sp = pd.get("start_point", {})
            ep = pd.get("end_point", {})
            sol_start = extract_svg_endpoint(solution_path, "start")
            sol_end = extract_svg_endpoint(solution_path, "end")
            if sol_start and sp:
                if abs(sol_start[0] - sp.get("x", 0)) > 5 or abs(sol_start[1] - sp.get("y", 0)) > 5:
                    errors.append(f"{filename}: solution_path start {sol_start} doesn't match start_point ({sp.get('x')},{sp.get('y')})")
            if sol_end and ep:
                if abs(sol_end[0] - ep.get("x", 0)) > 5 or abs(sol_end[1] - ep.get("y", 0)) > 5:
                    errors.append(f"{filename}: solution_path end {sol_end} doesn't match end_point ({ep.get('x')},{ep.get('y')})")

    # 3. Path complexity
    step_count = parse_solution_steps(solution_path)
    if difficulty == "medium" and maze_type != "organic" and step_count < 15:
        errors.append(f"{filename}: medium maze has only {step_count} solution steps (need >= 15)")
    if difficulty == "hard" and maze_type != "organic" and step_count < 25:
        errors.append(f"{filename}: hard maze has only {step_count} solution steps (need >= 25)")

    # 4. Content quality
    if not data.get("story_setup", "").strip():
        errors.append(f"{filename}: story_setup is empty")
    if not data.get("educational_question", "").strip():
        errors.append(f"{filename}: educational_question is empty")
    elif not data.get("educational_question", "").strip().endswith("?"):
        errors.append(f"{filename}: educational_question doesn't end with '?'")

    # 5. SVG validity
    svg_path = pd.get("svg_path", "")
    if not svg_path or not svg_path.strip():
        errors.append(f"{filename}: svg_path is empty")
    elif not svg_path.strip().startswith("M"):
        errors.append(f"{filename}: svg_path doesn't start with 'M'")

    # 7. Visual theme validation
    bg_color = vt.get("background_color", "")
    if bg_color and not HEX_COLOR_RE.match(bg_color):
        errors.append(f"{filename}: background_color '{bg_color}' is not valid hex")

    dec_elements = vt.get("decorative_elements", [])
    if not dec_elements or len(dec_elements) == 0:
        errors.append(f"{filename}: decorative_elements is empty")

    return errors, warnings


def validate_manifest(labyrinths_dir, all_data):
    errors = []
    manifest_path = os.path.join(labyrinths_dir, "manifest.json")

    if not os.path.exists(manifest_path):
        return [f"manifest.json: file not found"]

    try:
        manifest = load_json(manifest_path)
    except json.JSONDecodeError as e:
        return [f"manifest.json: invalid JSON - {e}"]

    manifest_entries = manifest.get("labyrinths", [])
    manifest_ids = {entry["id"] for entry in manifest_entries if "id" in entry}
    file_ids = {d["id"] for d in all_data if "id" in d}

    # Check total count
    if manifest.get("total") != 30:
        errors.append(f"manifest.json: total is {manifest.get('total')}, expected 30")

    if len(manifest_entries) != 30:
        errors.append(f"manifest.json: lists {len(manifest_entries)} entries, expected 30")

    # Check all files are in manifest
    missing_from_manifest = file_ids - manifest_ids
    if missing_from_manifest:
        errors.append(f"manifest.json: files not in manifest: {missing_from_manifest}")

    extra_in_manifest = manifest_ids - file_ids
    if extra_in_manifest:
        errors.append(f"manifest.json: manifest has entries without files: {extra_in_manifest}")

    # Cross-check fields
    manifest_map = {e["id"]: e for e in manifest_entries if "id" in e}
    file_map = {d["id"]: d for d in all_data if "id" in d}
    for lab_id in manifest_ids & file_ids:
        m = manifest_map[lab_id]
        f = file_map[lab_id]
        for field in ["age_range", "difficulty", "theme", "title"]:
            if m.get(field) != f.get(field):
                errors.append(f"manifest.json: {lab_id}.{field} mismatch: manifest='{m.get(field)}' vs file='{f.get(field)}'")

    return errors


def main():
    all_errors = []
    all_warnings = []
    all_data = []
    titles = []

    # Validate each labyrinth file
    for i in range(1, 31):
        filename = f"lab_{i:03d}.json"
        filepath = os.path.join(LABYRINTHS_DIR, filename)

        if not os.path.exists(filepath):
            all_errors.append(f"{filename}: file not found")
            continue

        data = load_json(filepath)
        all_data.append(data)
        titles.append((filename, data.get("title", "")))

        errors, warnings = validate_labyrinth(filepath)
        all_errors.extend(errors)
        all_warnings.extend(warnings)

    # 4. Title uniqueness check
    title_values = [t[1] for t in titles]
    seen = {}
    for filename, title in titles:
        if title in seen:
            all_errors.append(f"Duplicate title '{title}' in {seen[title]} and {filename}")
        else:
            seen[title] = filename

    # 6. Manifest consistency
    manifest_errors = validate_manifest(LABYRINTHS_DIR, all_data)
    all_errors.extend(manifest_errors)

    # Report
    print("=" * 60)
    print("LABYRINTH CONTENT VALIDATION REPORT")
    print("=" * 60)
    print(f"Files checked: {len(all_data)}/30")
    print()

    if all_errors:
        print(f"ERRORS ({len(all_errors)}):")
        for e in all_errors:
            print(f"  [FAIL] {e}")
        print()
    else:
        print("NO ERRORS FOUND")
        print()

    if all_warnings:
        print(f"WARNINGS ({len(all_warnings)}):")
        for w in all_warnings:
            print(f"  [WARN] {w}")
        print()

    # Summary stats
    difficulties = {}
    maze_types = {}
    age_ranges = {}
    for d in all_data:
        diff = d.get("difficulty", "unknown")
        difficulties[diff] = difficulties.get(diff, 0) + 1
        mt = d.get("path_data", {}).get("maze_type", "unknown")
        maze_types[mt] = maze_types.get(mt, 0) + 1
        ar = d.get("age_range", "unknown")
        age_ranges[ar] = age_ranges.get(ar, 0) + 1

    print("DISTRIBUTION SUMMARY:")
    print(f"  Difficulties: {dict(sorted(difficulties.items()))}")
    print(f"  Maze types:   {dict(sorted(maze_types.items()))}")
    print(f"  Age ranges:   {dict(sorted(age_ranges.items()))}")
    print()

    if all_errors:
        print(f"RESULT: FAILED ({len(all_errors)} errors)")
        return 1
    else:
        print("RESULT: PASSED - All 30 labyrinths validated successfully")
        return 0


if __name__ == "__main__":
    sys.exit(main())
