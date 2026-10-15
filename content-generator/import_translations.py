#!/usr/bin/env python3
"""Validate returned translation sheets and generate app and audio resources."""

from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / "content-generator/localized-audio"
APP = ROOT / "LowDopamineLabyrinth/LowDopamineLabyrinth"
EXPECTED = {row["key"]: row for row in csv.DictReader(
    (PACKS / "translations-de.csv").open(encoding="utf-8-sig")
)}


def read_locale(locale: str) -> dict[str, dict[str, str]]:
    path = ROOT / f"translations-{locale}-filled.csv"
    if not path.exists():
        raise SystemExit(f"Missing translation file: {path.name}")
    rows = list(csv.DictReader(path.open(encoding="utf-8-sig", newline="")))
    actual = {row.get("key", ""): row for row in rows}
    if len(actual) != len(rows):
        raise SystemExit(f"{path.name} has duplicate or blank keys")
    missing = EXPECTED.keys() - actual.keys()
    extra = actual.keys() - EXPECTED.keys()
    if missing or extra:
        raise SystemExit(f"{path.name}: {len(missing)} missing keys, {len(extra)} unknown keys")
    translations: dict[str, dict[str, str]] = {}
    for key, row in actual.items():
        expected = EXPECTED[key]
        if row.get("source") != expected["source"] or row.get("category") != expected["category"]:
            raise SystemExit(f"{path.name}: source/category changed for {key}")
        value = (row.get("translation") or "").strip()
        if not value:
            raise SystemExit(f"{path.name}: translation is blank for {key}")
        translations.setdefault(row["category"], {})[row["source"]] = value
    return translations


def string_catalog(locales: dict[str, dict[str, dict[str, str]]]) -> dict:
    all_ui: dict[str, dict[str, str]] = {}
    for locale, categories in locales.items():
        all_ui[locale] = categories.get("ui", {})
    sources = set().union(*(set(mapping) for mapping in all_ui.values()))
    catalog_strings = {}
    for source in sorted(sources):
        entry: dict = {"extractionState": "manual", "localizations": {}}
        for locale, translations in all_ui.items():
            value = translations.get(source)
            if value is not None:
                entry["localizations"][locale] = {
                    "stringUnit": {"state": "translated", "value": value}
                }
        catalog_strings[source] = entry
    return {"sourceLanguage": "en", "strings": catalog_strings, "version": "1.0"}


def main() -> None:
    locales = {locale: read_locale(locale) for locale in ("de", "es")}
    # Difficulty names are derived from enum case names in Swift, not stored as
    # literals in the translation sheet.
    locales["de"]["ui"].update({"Easy": "Einfach", "Medium": "Mittel", "Hard": "Schwer"})
    locales["es"]["ui"].update({"Easy": "Fácil", "Medium": "Medio", "Hard": "Difícil"})
    APP.joinpath("Localizable.xcstrings").write_text(
        json.dumps(string_catalog(locales), ensure_ascii=False, indent=2) + "\n"
    )

    content = {locale: {category: values for category, values in groups.items()
                        if category.startswith("story.") or category == "shared.narration"}
               for locale, groups in locales.items()}
    (APP / "Resources" / "story-localizations.json").write_text(
        json.dumps(content, ensure_ascii=False, indent=2) + "\n"
    )
    ui_copy = {locale: groups["ui"] for locale, groups in locales.items()}
    (APP / "Resources" / "ui-localizations.json").write_text(
        json.dumps(ui_copy, ensure_ascii=False, indent=2) + "\n"
    )

    for locale, groups in locales.items():
        audio_by_key: dict[str, str] = {}
        with (ROOT / f"translations-{locale}-filled.csv").open(encoding="utf-8-sig", newline="") as stream:
            for row in csv.DictReader(stream):
                filename = (row.get("audio_filename") or "").strip()
                if filename:
                    audio_by_key[Path(filename).stem] = row["translation"].strip()
        if len(audio_by_key) != 200:
            raise SystemExit(f"{locale}: expected 200 narration strings, found {len(audio_by_key)}")
        (PACKS / f"narration-{locale}.json").write_text(
            json.dumps(audio_by_key, ensure_ascii=False, indent=2) + "\n"
        )
    print("Generated Localizable.xcstrings, story-localizations.json, and narration scripts for de/es")


if __name__ == "__main__":
    main()
