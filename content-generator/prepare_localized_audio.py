#!/usr/bin/env python3
"""Export the app's narration source text as translation-ready locale files."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LABYRINTHS = ROOT / "LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths"
OUTPUT = ROOT / "content-generator/localized-audio"


def main() -> None:
    manifest = json.loads((LABYRINTHS / "manifest.json").read_text())
    by_story: dict[int, list[dict]] = {}
    for entry in manifest["labyrinths"]:
        if entry.get("story") is not None:
            by_story.setdefault(entry["story"], []).append(entry)

    source: dict[str, str] = {}
    for story, entries in sorted(by_story.items()):
        preferred = next((e for e in entries if e["difficulty"] == "easy"), entries[0])
        data = json.loads((LABYRINTHS / f"{preferred['id']}.json").read_text())
        for field, key in (("tts_instruction", "instruction"),
                            ("fun_fact", "answer"),
                            ("completion_message", "completion")):
            value = data.get(field, "").strip()
            if value:
                source[f"denny_{story:03d}_{key}"] = value

    # Shared tracks are generated from their existing source scripts when present.
    shared_path = OUTPUT / "shared-narration-source.json"
    if shared_path.exists():
        source.update(json.loads(shared_path.read_text()))

    OUTPUT.mkdir(parents=True, exist_ok=True)
    for locale in ("de", "es"):
        destination = OUTPUT / f"narration-{locale}-template.json"
        destination.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n")
        print(f"Wrote {len(source)} narration entries to {destination.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
