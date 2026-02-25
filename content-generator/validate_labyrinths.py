"""Validate all labyrinth JSON files for quality issues."""
import json
import math
import re
from pathlib import Path
from collections import defaultdict

LAB_DIR = Path(__file__).parent.parent / "LowDopamineLabyrinth" / "LowDopamineLabyrinth" / "Resources" / "Labyrinths"

# Target item counts per difficulty (all collect)
COLLECT_TARGETS = {"beginner": 2, "easy": 3, "medium": 4, "hard": 5, "expert": 6}

# Minimum solution segment counts per difficulty
MIN_SEGMENTS = {"beginner": 3, "easy": 6, "medium": 12, "hard": 20, "expert": 35}

# Minimum start-end pixel distance
MIN_START_END_DIST = 150

# Max start Y (to avoid iOS curtain — top of canvas is ~40-80)
MAX_START_Y_TOP = 100  # if start_y <= this, it's "at the top"


def count_svg_segments(svg_path: str) -> int:
    """Count M (move-to) commands in SVG path = number of line segments."""
    return svg_path.count("M ")


def parse_svg_bounds(svg_path: str):
    """Parse SVG path to find coordinate bounds."""
    nums = re.findall(r'[\d.]+', svg_path)
    if len(nums) < 2:
        return None
    pairs = [(float(nums[i]), float(nums[i+1])) for i in range(0, len(nums)-1, 2)]
    xs = [p[0] for p in pairs]
    ys = [p[1] for p in pairs]
    return min(xs), max(xs), min(ys), max(ys)


def validate_labyrinth(lab: dict) -> list:
    """Validate a single labyrinth. Returns list of (issue_type, description)."""
    issues = []
    lab_id = lab["id"]
    difficulty = lab["difficulty"]
    pd = lab["path_data"]
    is_corridor = pd["maze_type"].startswith("corridor")
    is_adventure = lab.get("item_rule") is not None
    item_rule = lab.get("item_rule")

    start = pd["start_point"]
    end = pd["end_point"]
    segments = pd["segments"]
    items = pd.get("items", [])

    # 1. Solution path length (segment count)
    seg_count = len(segments)
    min_segs = MIN_SEGMENTS.get(difficulty, 10)
    if seg_count < min_segs:
        issues.append(("SHORT_SOLUTION",
            f"Solution has {seg_count} segments (min {min_segs} for {difficulty})"))

    # 2. Start-end distance
    dx = start["x"] - end["x"]
    dy = start["y"] - end["y"]
    dist = math.sqrt(dx*dx + dy*dy)
    if dist < MIN_START_END_DIST:
        issues.append(("CLOSE_START_END",
            f"Start-end distance {dist:.0f}px (min {MIN_START_END_DIST})"))

    # 3. Start not at top
    if start["y"] <= MAX_START_Y_TOP:
        issues.append(("START_AT_TOP",
            f"Start Y={start['y']:.0f} is at the top (max {MAX_START_Y_TOP})"))

    # 4. Item count vs target (adventure mazes only)
    if is_adventure and item_rule == "collect":
        target = COLLECT_TARGETS.get(difficulty, 3)
        actual = len(items)
        if actual < max(1, int(target * 0.5)):
            issues.append(("LOW_ITEM_COUNT",
                f"collect: {actual} items (target {target}, min {max(1, int(target*0.5))})"))

    # 7. SVG path complexity (corridor mazes should have enough corridors)
    if is_corridor:
        svg_segs = count_svg_segments(pd["svg_path"])
        # A corridor maze should have significantly more SVG segments than solution segments
        # (dead-end branches, etc.)
        min_svg = min_segs * 2  # at least 2x the solution
        if svg_segs < min_svg:
            issues.append(("SIMPLE_MAZE",
                f"Corridor maze has {svg_segs} SVG segments (min {min_svg} for {difficulty})"))

    # 8. Items within maze bounds (not clipped)
    canvas_w = pd["canvas_width"]
    canvas_h = pd["canvas_height"]
    for i, item in enumerate(items):
        if item["x"] < 10 or item["x"] > canvas_w - 10:
            issues.append(("ITEM_OUT_OF_BOUNDS", f"Item {i} x={item['x']:.0f} out of canvas"))
        if item["y"] < 10 or item["y"] > canvas_h - 10:
            issues.append(("ITEM_OUT_OF_BOUNDS", f"Item {i} y={item['y']:.0f} out of canvas"))

    return issues


def main():
    json_files = sorted(LAB_DIR.glob("denny_*_lv*.json"))
    print(f"Validating {len(json_files)} labyrinth files...\n")

    all_issues = {}
    issue_counts = defaultdict(int)
    difficulty_issues = defaultdict(lambda: defaultdict(int))

    for path in json_files:
        with open(path) as f:
            lab = json.load(f)
        issues = validate_labyrinth(lab)
        if issues:
            all_issues[lab["id"]] = issues
            for issue_type, desc in issues:
                issue_counts[issue_type] += 1
                difficulty_issues[lab["difficulty"]][issue_type] += 1

    # Print summary by issue type
    total_files = len(json_files)
    total_failing = len(all_issues)
    print(f"{'='*70}")
    print(f"VALIDATION SUMMARY: {total_failing}/{total_files} labyrinths have issues")
    print(f"{'='*70}\n")

    print("ISSUE COUNTS BY TYPE:")
    for issue_type, count in sorted(issue_counts.items(), key=lambda x: -x[1]):
        print(f"  {issue_type}: {count}")

    print(f"\nISSUES BY DIFFICULTY LEVEL:")
    for diff in ["beginner", "easy", "medium", "hard", "expert"]:
        if diff in difficulty_issues:
            total_at_diff = sum(1 for p in json_files
                               for _ in [1] if diff in p.name.split("_lv")[0] or True)
            issues_at_diff = difficulty_issues[diff]
            print(f"\n  {diff.upper()}:")
            for issue_type, count in sorted(issues_at_diff.items(), key=lambda x: -x[1]):
                print(f"    {issue_type}: {count}")

    print(f"\n{'='*70}")
    print("DETAILED FAILURES:")
    print(f"{'='*70}")
    for lab_id, issues in sorted(all_issues.items()):
        print(f"\n  {lab_id}:")
        for issue_type, desc in issues:
            print(f"    [{issue_type}] {desc}")


if __name__ == "__main__":
    main()
