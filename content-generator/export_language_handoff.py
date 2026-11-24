#!/usr/bin/env python3
"""Export current app translation keys while retaining historical key identities.

This prepares translation sheets only; it does not modify app resources or the
historical German, Spanish, Japanese, or Chinese translation files.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from export_translation_files import APP, LINE_LITERAL, ROOT, STORIES, story_rows, ui_rows, unescape_swift

PACKS = ROOT / "content-generator/localized-audio"
REGISTRY = ROOT / "content/localization/keys.json"
FIELDS = ["key", "category", "source", "context", "audio_filename", "translation"]
INTERPOLATION = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
FORMATS = re.compile(r"%(?:\d+\$)?[-+#0 ]*\d*(?:\.\d+)?(?:ll|l|z|h)?[@diufFeEgGcs]")
DERIVED_UI = {name: "Models/UserPreferences.swift; DifficultyLevel.displayName capitalizes the enum value"
              for name in ("Easy", "Medium", "Hard")}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def historical_keys() -> tuple[dict[tuple[str, str], str], dict[str, tuple[str, str]]]:
    by_identity, by_key = {}, {}
    for path in [PACKS / "translations-de.csv", ROOT / "translations-ja-complete.csv"]:
        for row in read_csv(path):
            identity = row["category"], row["source"]
            if row["key"] in by_key:
                assert by_key[row["key"]] == identity, f"Conflicting historical key: {row['key']}"
            by_identity.setdefault(identity, row["key"])
            by_key[row["key"]] = identity
    return by_identity, by_key


def is_copy(source: str) -> bool:
    if source.startswith(("[", "M ", "Failed to ", "Purchase failed:", "The bundled ",
                          "MetricKit ", "domain=", "description=", "http://", "https://")):
        return False
    if source in {"ABCDEFGHIJKLMNOPQRSTUVWXYZ", "CFBundleShortVersionString", "CFBundleVersion", "MockLanguageAudio",
                  "XCTestConfigurationFilePath"}:
        return False
    if "@" in source and " " not in source:  # Contact addresses remain literal.
        return False
    text = INTERPOLATION.sub("", source)
    if FORMATS.search(source):
        return True
    if not re.search(r"[A-Za-z]{2}", text):
        return False
    if " " not in text and any(mark in text for mark in (".", "/", "_", "\\")):
        return False
    return True


def current_ui_rows() -> list[dict[str, str]]:
    occurrences = defaultdict(set)
    for path in sorted(APP.rglob("*.swift")):
        for line_number, line in enumerate(path.read_text().splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            for literal in LINE_LITERAL.findall(line):
                occurrences[unescape_swift(literal)].add(f"{path.relative_to(APP)}:{line_number}")
    catalog = json.loads((APP / "Localizable.xcstrings").read_text())["strings"]
    dictionaries = json.loads((APP / "Resources/ui-localizations.json").read_text())
    candidates = set(catalog)
    candidates.update(DERIVED_UI)
    candidates.update(row["source"] for row in ui_rows())
    for translations in dictionaries.values():
        candidates.update(translations)
    rows = []
    for source in sorted(candidates):
        if not is_copy(source):
            continue
        contexts = occurrences.get(source)
        if not contexts and source in DERIVED_UI:
            contexts = {DERIVED_UI[source]}
        if not contexts and not FORMATS.search(source):
            continue  # No longer used by the current Swift source.
        rows.append({"category": "ui", "source": source,
                     "context": "; ".join(sorted(contexts)) if contexts else "Localizable.xcstrings; SwiftUI format key",
                     "audio_filename": "", "translation": ""})
    return rows


def active_rows(manifest: dict) -> tuple[list[dict[str, str]], set[str]]:
    active = {entry["id"] for entry in manifest["labyrinths"]}
    result = current_ui_rows()
    for row in story_rows():
        if row["category"] != "shared.narration":
            refs = [ref for ref in row["context"].split("; ") if ref.split()[0] in active]
            if not refs:
                continue
            row["context"] = "; ".join(refs)
        result.append({field: row[field] for field in FIELDS if field != "key"})
    return result, active


def assign_keys(rows: list[dict[str, str]], history: dict, reserved: dict) -> None:
    for row in rows:
        identity = row["category"], row["source"]
        if identity in history:
            row["key"] = history[identity]
            continue
        digest = hashlib.sha256(row["source"].encode()).hexdigest()[:12]
        if row["category"] == "ui":
            slug = re.sub(r"[^a-z0-9]+", ".", row["source"].lower()).strip(".")
            key = f"ui.{slug or digest}"
            if key in reserved and reserved[key] != identity:
                key += f".{digest}"
        else:
            key = f"{row['category']}.{digest}"
        assert key not in reserved or reserved[key] == identity, key
        row["key"] = key
        reserved[key] = identity


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        writer.writerows(rows)


def validate(rows: list[dict[str, str]], manifest: dict, active: set[str]) -> dict:
    assert len({r["key"] for r in rows}) == len(rows), "Duplicate translation keys"
    assert len({(r["category"], r["source"]) for r in rows}) == len(rows), "Duplicate source identities"
    assert all(r["key"] and r["source"] and not r["translation"] for r in rows)
    identities = {(r["category"], r["source"]) for r in rows}
    fields = {"title": "story.title", "story_setup": "story.setup", "instruction": "story.instruction",
              "tts_instruction": "story.narration_instruction", "educational_question": "story.question",
              "fun_fact": "story.narration_answer", "completion_message": "story.narration_completion",
              "location": "story.location", "item_rule": "story.item_rule"}
    for identifier in active:
        level = json.loads((STORIES / f"{identifier}.json").read_text())
        for field, category in fields.items():
            if level.get(field):
                assert (category, level[field].strip()) in identities, (identifier, field)
        for field in ("character_start", "character_end"):
            if level[field].get("name"):
                assert ("story.character_name", level[field]["name"].strip()) in identities
    audio = [r["audio_filename"] for r in rows if r["audio_filename"]]
    expected_audio = {p.name for p in (STORIES / "audio").glob("*.mp3")}
    assert len(audio) == len(set(audio)), "An audio filename is assigned to multiple sources"
    assert set(audio) == expected_audio, ("Narration coverage mismatch", expected_audio - set(audio), set(audio) - expected_audio)
    for source in ("Easy", "Medium", "Hard", "Trace Letters", "Trace Numbers", "Numbers", "10 numbers",
                   "Letters", "26 letters", "Free · 10 numbers", "Choose your language", "Denny's Thanksgiving"):
        assert ("ui", source) in identities, source
    return {"total_keys": len(rows), "categories": dict(sorted(Counter(r["category"] for r in rows).items())),
            "active_stories": len({entry["story"] for entry in manifest["labyrinths"]}),
            "active_levels": len(active), "narration_tracks": len(audio),
            "placeholders": {r["key"]: INTERPOLATION.findall(r["source"]) + FORMATS.findall(r["source"])
                             for r in rows if INTERPOLATION.search(r["source"]) or FORMATS.search(r["source"])}}


def build_registry(previous: dict | None) -> dict:
    manifest = json.loads((STORIES / "manifest.json").read_text())
    rows, active = active_rows(manifest)
    if previous is None:
        history, reserved = historical_keys()
        historical_ids = set(reserved)
    else:
        saved = previous["keys"] + previous["retired_keys"]
        history = {(row["category"], row["source"]): row["key"] for row in saved}
        reserved = {row["key"]: (row["category"], row["source"]) for row in saved}
        historical_ids = set(previous["historical_key_ids"])
    assign_keys(rows, history, reserved)
    report = validate(rows, manifest, active)
    report["reused_historical_keys"] = sum(r["key"] in historical_ids for r in rows)
    report["new_keys"] = len(rows) - report["reused_historical_keys"]
    thanksgiving = next(pack for pack in manifest["packs"] if pack["id"] == "thanksgiving_adventures")
    thanksgiving_ids = {entry["id"] for entry in manifest["labyrinths"] if entry.get("story") in thanksgiving["stories"]}
    thanksgiving_rows = [r for r in rows if r["source"] == thanksgiving["title"]
                         or any(ref.split()[0] in thanksgiving_ids for ref in r["context"].split("; "))]
    report["thanksgiving_keys"] = len(thanksgiving_rows)
    report["thanksgiving_narration_tracks"] = sum(bool(r["audio_filename"]) for r in thanksgiving_rows)
    report["story_numbers"] = sorted({entry["story"] for entry in manifest["labyrinths"]})
    report["packs"] = [pack["id"] for pack in manifest["packs"]]
    current_ids = {row["key"] for row in rows}
    return {
        "schema_version": 1,
        "source_language": "en",
        "coverage": report,
        "keys": [{field: row[field] for field in FIELDS if field != "translation"} for row in rows],
        "groups": {"thanksgiving_adventures": [row["key"] for row in thanksgiving_rows]},
        "historical_key_ids": sorted(historical_ids),
        "retired_keys": [{"key": key, "category": identity[0], "source": identity[1]}
                         for key, identity in sorted(reserved.items()) if key not in current_ids],
    }


def read_registry(path: Path) -> dict:
    if not path.exists():
        raise SystemExit(f"Missing key registry: {path}. Run this exporter with --sync-registry first.")
    data = json.loads(path.read_text())
    assert data["schema_version"] == 1 and data["source_language"] == "en"
    all_rows = data["keys"] + data["retired_keys"]
    assert len({row["key"] for row in all_rows}) == len(all_rows), "Duplicate registry key IDs"
    assert len({(row["category"], row["source"]) for row in all_rows}) == len(all_rows), "Duplicate registry source identities"
    assert all(row["key"] and row["category"] and row["source"] for row in all_rows)
    assert len(data["keys"]) == data["coverage"]["total_keys"]
    assert dict(Counter(row["category"] for row in data["keys"])) == data["coverage"]["categories"]
    audio = [row["audio_filename"] for row in data["keys"] if row["audio_filename"]]
    assert len(audio) == len(set(audio)) == data["coverage"]["narration_tracks"]
    active_ids = {row["key"] for row in data["keys"]}
    assert all(set(ids) <= active_ids for ids in data["groups"].values())
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locales", nargs="+", choices=("ko", "ar", "sv", "fi", "nl"), default=["ko", "ar"])
    parser.add_argument("--output-dir", type=Path, default=PACKS / "translation-files-ko-ar")
    parser.add_argument("--registry", type=Path, default=REGISTRY)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--sync-registry", action="store_true", help="Update the saved registry from current app content, preserving existing and retired key IDs")
    mode.add_argument("--check-registry", action="store_true", help="Check registry coverage against current app content without writing files")
    args = parser.parse_args()
    if args.sync_registry or args.check_registry:
        previous = read_registry(args.registry) if args.registry.exists() else None
        current = build_registry(previous)
        if args.check_registry:
            if current != previous:
                raise SystemExit("Translation key registry is out of date. Run with --sync-registry and include the update with the content change.")
            print(f"Registry is current: {len(current['keys'])} keys, {current['coverage']['narration_tracks']} audio references.")
        else:
            args.registry.parent.mkdir(parents=True, exist_ok=True)
            args.registry.write_text(json.dumps(current, ensure_ascii=False, indent=2) + "\n")
            print(f"Saved {len(current['keys'])} current keys and {len(current['retired_keys'])} retired key identities to {args.registry.relative_to(ROOT) if args.registry.is_relative_to(ROOT) else args.registry}")
        return
    registry = read_registry(args.registry)
    rows = [{**row, "translation": ""} for row in registry["keys"]]
    report = dict(registry["coverage"])
    thanksgiving_ids = set(registry["groups"]["thanksgiving_adventures"])
    thanksgiving_rows = [row for row in rows if row["key"] in thanksgiving_ids]
    report["locales"] = args.locales
    output = args.output_dir
    output.mkdir(parents=True, exist_ok=True)
    files = []
    for locale in args.locales:
        path = output / f"translations-{locale}.csv"
        if path.exists() and any(r.get("translation", "").strip() for r in read_csv(path)):
            raise SystemExit(f"Refusing to overwrite translated work: {path}")
        write_csv(path, rows)
        assert read_csv(path) == rows, "CSV round-trip changed source text"
        files.append(path)
    write_csv(output / "thanksgiving-keys.csv", thanksgiving_rows)
    files.append(output / "thanksgiving-keys.csv")
    (output / "coverage.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    files.append(output / "coverage.json")
    language_names = {"ko": "Korean", "ar": "Arabic", "sv": "Swedish", "fi": "Finnish", "nl": "Dutch"}
    language_files = "\n".join(f"- `translations-{locale}.csv`: {language_names[locale]}." for locale in args.locales)
    readme = f'''# Translation files: {', '.join(language_names[locale] for locale in args.locales)}

Each complete sheet contains {len(rows)} entries covering the interface,
accessibility labels, {report['active_stories']} stories, and source text for
{report['narration_tracks']} audio recordings. The seven Thanksgiving stories
and current letter and number tracing labels are included. Archived Fall content
and the separate Christmas branch are excluded. App Store metadata and website
copy are handled separately.

The canonical source keys are stored in `content/localization/keys.json`.
Translation exports read that registry directly. Update it only when app content
changes, using `python3 content-generator/export_language_handoff.py --sync-registry`.

{language_files}
- `thanksgiving-keys.csv`: {len(thanksgiving_rows)} Thanksgiving entries for reference.
  These entries are already included in each complete sheet; do not translate them twice.
- `coverage.json`: coverage checks and placeholders grouped by key.

Fill only the `translation` column. Preserve `key`, `category`, `source`,
`context`, and `audio_filename`. The CSV files use UTF-8 with a BOM for Excel.
Return UTF-8 CSV files. Each CSV record is one translation entry, even when the
source text contains a line break.

Preserve placeholders such as `%@`, `%lld`, `\\(remaining)`, and `\\(emoji)`
exactly; move them within a sentence only when the language requires it.
Keep MP3 filenames, links, and identifiers unchanged. Do not replace Latin
letters, digits, or hiragana inside placeholders with other characters.

The stories are written for children ages 3–6. Preserve the task, item counts,
facts, and character identities. `story.setup`, `story.instruction`, and
`story.narration_instruction` may repeat the same text; translate them
consistently. Thanksgiving `completion` recordings speak the success message
followed by its question; translate these fields separately as listed.

For Arabic, write ordinary text in its natural reading order. Do not reverse
strings manually or add invisible direction-control characters. Use Modern
Standard Arabic (MSA) for the general interface.

These files prepare source keys for translation. After the translated CSV files
are reviewed, the languages and narration will be integrated into the app as a
separate step.
'''
    (output / "README.md").write_text(readme)
    files.append(output / "README.md")
    archive = output.with_suffix(".zip")
    with ZipFile(archive, "w", ZIP_DEFLATED) as bundle:
        for path in files:
            bundle.write(path, path.name)
    with ZipFile(archive) as bundle:
        assert bundle.testzip() is None
    print(f"Exported {len(rows)} keys per language; {report['active_stories']} stories; {report['narration_tracks']} narration tracks.")
    print(f"Thanksgiving: {len(thanksgiving_rows)} keys, {report['thanksgiving_narration_tracks']} recordings.")
    print(f"Historical IDs retained: {report['reused_historical_keys']}; new IDs: {report['new_keys']}.")
    print(f"Translation package: {archive.relative_to(ROOT) if archive.is_relative_to(ROOT) else archive}")


if __name__ == "__main__":
    main()
