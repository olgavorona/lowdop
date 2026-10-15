#!/usr/bin/env python3
"""Export app UI and story copy as spreadsheet-ready translation CSVs."""

from __future__ import annotations

import csv
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LowDopamineLabyrinth/LowDopamineLabyrinth"
STORIES = APP / "Resources/Labyrinths"
OUT = ROOT / "content-generator/localized-audio"

SWIFT_CALL = re.compile(
    r"\b(Text|Button|Label|SectionHeader|AccountButton|AccountRow)\s*\(\s*\"((?:\\.|[^\"\\])*)\"|"
    r"\.?(?:accessibilityLabel|navigationTitle)\s*\(\s*\"((?:\\.|[^\"\\])*)\""
)
LINE_LITERAL = re.compile(r'\"((?:\\.|[^\"\\])*)\"')


def unescape_swift(value: str) -> str:
    return (value.replace(r"\n", "\n").replace(r"\t", "\t")
            .replace(r'\"', '"').replace(r"\\", "\\"))


def ui_rows() -> list[dict[str, str]]:
    rows: dict[str, dict[str, str]] = {}
    for path in sorted(APP.rglob("*.swift")):
        lines = path.read_text().splitlines()
        for number, line in enumerate(lines, 1):
            if line.lstrip().startswith("//"):
                continue
            candidates: list[str] = []
            for match in SWIFT_CALL.finditer(line):
                candidate = match.group(2) or match.group(3)
                if candidate:
                    candidates.append(unescape_swift(candidate))
            # Also collect helper arguments, returned paywall copy, and branches
            # in interpolated Text expressions that aren't direct Text literals.
            for literal in LINE_LITERAL.findall(line):
                value = unescape_swift(literal)
                looks_like_copy = (
                    " " in value
                    or (value[:1].isupper() and not any(mark in value for mark in (".", "/", "_")))
                )
                if looks_like_copy:
                    candidates.append(value)
            for source in candidates:
                if not source.strip() or source in {"·", "|", "•"}:
                    continue
                key = "ui." + re.sub(r"[^a-z0-9]+", ".", source.lower()).strip(".")
                rows.setdefault(key, {
                    "key": key,
                    "category": "ui",
                    "source": source,
                    "context": f"{path.name}:{number}",
                    "audio_filename": "",
                    "translation": "",
                })
    return list(rows.values())


def story_rows() -> list[dict[str, str]]:
    rows: dict[tuple[str, str], dict[str, str]] = {}
    translatable = {
        "title": ("story.title", ""),
        "story_setup": ("story.setup", ""),
        "instruction": ("story.instruction", ""),
        "tts_instruction": ("story.narration_instruction", "instruction"),
        "educational_question": ("story.question", ""),
        "fun_fact": ("story.narration_answer", "answer"),
        "completion_message": ("story.narration_completion", "completion"),
        "item_rule": ("story.item_rule", ""),
        "location": ("story.location", ""),
    }
    for path in sorted(STORIES.glob("denny_*.json")):
        try:
            data = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        story_id = data.get("id", path.stem)
        for field, (category, audio_suffix) in translatable.items():
            value = data.get(field)
            if not isinstance(value, str) or not value.strip():
                continue
            identity = (category, value.strip())
            audio_filename = ""
            if audio_suffix:
                match = re.search(r"denny_(\d+)", story_id)
                if match:
                    audio_filename = f"denny_{int(match.group(1)):03d}_{audio_suffix}.mp3"
            if identity not in rows:
                rows[identity] = {
                    "key": f"{category}.{len(rows) + 1:04d}",
                    "category": category,
                    "source": value.strip(),
                    "context": story_id,
                    "audio_filename": audio_filename,
                    "translation": "",
                }
            else:
                row = rows[identity]
                refs = set(row["context"].split("; "))
                refs.add(story_id)
                row["context"] = "; ".join(sorted(refs))
        for part in ("character_start", "character_end"):
            name = (data.get(part) or {}).get("name")
            if isinstance(name, str) and name.strip():
                category = "story.character_name"
                identity = (category, name.strip())
                if identity not in rows:
                    rows[identity] = {
                        "key": f"{category}.{len(rows) + 1:04d}",
                        "category": category,
                        "source": name.strip(),
                        "context": f"{story_id} {part}",
                        "audio_filename": "",
                        "translation": "",
                    }
                else:
                    refs = set(rows[identity]["context"].split("; "))
                    refs.add(f"{story_id} {part}")
                    rows[identity]["context"] = "; ".join(sorted(refs))
    # The tutorial recording uses the tutorial's spoken instruction. The gate's
    # spoken line matches its on-screen prompt.
    onboarding = (APP / "Views/OnboardingView.swift").read_text()
    match = re.search(r'ttsInstruction:\s*"((?:\\.|[^"\\])*)"', onboarding)
    if match:
        rows[("shared.narration", unescape_swift(match.group(1)))] = {
            "key": "audio.onboarding_trace_intro",
            "category": "shared.narration",
            "source": unescape_swift(match.group(1)),
            "context": "Onboarding tutorial voice-over",
            "audio_filename": "onboarding_trace_intro.mp3",
            "translation": "",
        }
    gate_source = "Please ask a grown-up to answer this question:"
    rows[("shared.narration", gate_source)] = {
        "key": "audio.parental_gate",
        "category": "shared.narration",
        "source": gate_source,
        "context": "Parental gate voice-over",
        "audio_filename": "parental_gate.mp3",
        "translation": "",
    }
    return list(rows.values())


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fields = ["key", "category", "source", "context", "audio_filename", "translation"]
    rows = ui_rows() + story_rows()
    for locale in ("de", "es"):
        target = OUT / f"translations-{locale}.csv"
        with target.open("w", newline="", encoding="utf-8-sig") as stream:
            writer = csv.DictWriter(stream, fieldnames=fields, quoting=csv.QUOTE_ALL)
            writer.writeheader()
            writer.writerows(rows)
        print(f"Wrote {len(rows)} rows to {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
