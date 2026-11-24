#!/usr/bin/env python3
"""Validate and import translated CSVs using the saved key registry."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil

from export_language_handoff import APP, FIELDS, FORMATS, INTERPOLATION, PACKS, ROOT, STORIES, read_csv, read_registry, REGISTRY, write_csv

SAVED = ROOT / "content/localization/translations"


def placeholders(text: str) -> Counter:
    return Counter(INTERPOLATION.findall(text) + FORMATS.findall(text))


def validate_file(path: Path, expected: dict, keys: set[str]) -> dict:
    rows = read_csv(path)
    actual = {row.get("key", ""): row for row in rows}
    if len(actual) != len(rows) or not all(actual):
        raise ValueError(f"{path.name}: duplicate or blank keys")
    if set(actual) != keys:
        raise ValueError(f"{path.name}: missing={sorted(keys-set(actual))}, unknown={sorted(set(actual)-keys)}")
    for key, row in actual.items():
        source = expected[key]
        for field in ("source", "category", "audio_filename"):
            if row.get(field) != source[field]:
                raise ValueError(f"{path.name}: {field} changed for {key}")
        text = row.get("translation", "").strip()
        if not text:
            raise ValueError(f"{path.name}: blank translation for {key}")
        if placeholders(text) != placeholders(source["source"]):
            raise ValueError(f"{path.name}: placeholders changed for {key}")
        if source["category"] == "story.item_rule" and text != source["source"]:
            raise ValueError(f"{path.name}: gameplay rule identifiers must remain unchanged: {key}")
        row["translation"] = text
    return actual


def write_json(path: Path, data, catalog: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2,
                               separators=(",", " : ") if catalog else (",", ": ")) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=SAVED / "source")
    parser.add_argument("--locales", nargs="+", choices=("ko", "ar", "sv", "fi", "nl"), default=["ko", "ar"])
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    registry = read_registry(REGISTRY)
    expected = {row["key"]: row for row in registry["keys"]}
    thanksgiving = set(registry["groups"]["thanksgiving_adventures"])
    overrides = json.loads((ROOT / "content/localization/display-label-overrides.json").read_text())
    manifest = json.loads((STORIES / "manifest.json").read_text())
    levels = {}
    for entry in manifest["labyrinths"]:
        levels.setdefault(entry["story"], json.loads((STORIES / f"{entry['id']}.json").read_text()))
    imported, normalized, narrations, report = {}, {}, {}, {}
    for locale in args.locales:
        full_path = args.input_dir / f"translations-{locale}.csv"
        seasonal_path = args.input_dir / f"thanksgiving-{locale}.csv"
        full = validate_file(full_path, expected, set(expected))
        seasonal = validate_file(seasonal_path, expected, thanksgiving)
        for key, row in seasonal.items():
            if row["translation"] != full[key]["translation"]:
                raise ValueError(f"{locale}: Thanksgiving and full-sheet translations disagree for {key}")
        groups, corrections, merged = {}, [], []
        for source in registry["keys"]:
            row = dict(full[source["key"]])
            text = row["translation"]
            if source["category"] == "story.location" and text == source["source"]:
                text = overrides.get(locale, {}).get("story.location", {}).get(source["source"], text)
                if text == source["source"]:
                    raise ValueError(f"{locale}: untranslated location label for {source['key']}")
                corrections.append(source["key"])
            row["translation"] = text
            groups.setdefault(source["category"], {})[source["source"]] = text
            merged.append({field: row.get(field, "") for field in FIELDS})
        audio = {Path(row["audio_filename"]).stem: row["translation"] for row in merged if row["audio_filename"]}
        for number, level in levels.items():
            if level["theme"] == "thanksgiving":
                audio[f"denny_{number:03d}_completion"] = (
                    groups["story.narration_completion"][level["completion_message"]] + " " +
                    groups["story.question"][level["educational_question"]]
                )
        assert {f"{key}.mp3" for key in audio} == {p.name for p in (STORIES / "audio").glob("*.mp3")}
        imported[locale], normalized[locale], narrations[locale] = groups, merged, audio
        report[locale] = {"keys": len(full), "thanksgiving_keys": len(seasonal), "audio_scripts": len(audio),
                          "display_label_corrections": corrections,
                          "source_files": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (full_path, seasonal_path)}}
        print(f"{locale}: {len(full)} validated translations, {len(seasonal)} matching Thanksgiving entries, {len(audio)} narration scripts; {len(corrections)} location labels localized")
    if args.validate_only:
        return
    paths = {"catalog": APP / "Localizable.xcstrings", "story": APP / "Resources/story-localizations.json",
             "ui": APP / "Resources/ui-localizations.json"}
    catalog = json.loads(paths["catalog"].read_text())
    story = json.loads(paths["story"].read_text())
    ui = json.loads(paths["ui"].read_text())
    original_catalog, original_story, original_ui = json.loads(json.dumps(catalog)), json.loads(json.dumps(story)), json.loads(json.dumps(ui))
    for locale, groups in imported.items():
        for source, text in groups["ui"].items():
            entry = catalog["strings"].setdefault(source, {"extractionState": "manual", "localizations": {}})
            entry.setdefault("localizations", {})[locale] = {"stringUnit": {"state": "translated", "value": text}}
        story[locale] = {category: values for category, values in groups.items() if category != "ui"}
        ui[locale] = groups["ui"]
        SAVED.mkdir(parents=True, exist_ok=True)
        (SAVED / "source").mkdir(exist_ok=True)
        for prefix in ("translations", "thanksgiving"):
            source_file = args.input_dir / f"{prefix}-{locale}.csv"
            target = SAVED / "source" / source_file.name
            if source_file.resolve() != target.resolve():
                shutil.copy2(source_file, target)
        write_csv(SAVED / f"translations-{locale}.csv", normalized[locale])
        write_json(PACKS / f"narration-{locale}.json", narrations[locale])
    for locale in original_story:
        if locale not in imported:
            assert story[locale] == original_story[locale] and ui[locale] == original_ui[locale]
    for source, entry in original_catalog["strings"].items():
        for locale, value in entry.get("localizations", {}).items():
            if locale not in imported:
                assert catalog["strings"][source]["localizations"][locale] == value
    write_json(paths["catalog"], catalog, catalog=True)
    write_json(paths["story"], story)
    write_json(paths["ui"], ui)
    report_path = SAVED / "import-report.json"
    previous_report = json.loads(report_path.read_text()) if report_path.exists() else {}
    write_json(report_path, {**previous_report, **report})
    print(f"Imported {', '.join(imported)} resources; existing locale translations are preserved.")


if __name__ == "__main__":
    main()
