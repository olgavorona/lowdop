#!/usr/bin/env python3
"""Update only the approved Swedish, Finnish, and Dutch App Store descriptions."""

import argparse
import hashlib
import json
from pathlib import Path
import re

from publish_app_store_build import all_rows, client

LOCALES = {"sv", "fi", "nl-NL"}
APP_ID = "6760107138"
VERSION = "1.5.4"


def digest(text):
    return hashlib.sha256(text.strip().encode("utf-8")).hexdigest()


def structure(text):
    return [(len(block.splitlines()), block.startswith("### "), block.startswith("• "))
            for block in text.strip().split("\n\n")]


def load_plan(path):
    plan = json.loads(path.read_text())
    if plan["app_id"] != APP_ID or plan["version"] != VERSION:
        raise ValueError("Unexpected app or version")
    if set(plan["descriptions"]) != LOCALES or set(plan["previous_description_sha256"]) != LOCALES:
        raise ValueError("Only Swedish, Finnish, and Dutch descriptions are approved")
    source = plan["english_description"]
    for locale, text in plan["descriptions"].items():
        if not isinstance(text, str) or not 0 < len(text) <= 4000:
            raise ValueError(f"{locale}: invalid description")
        if structure(text) != structure(source) or re.findall(r"\d+", text) != re.findall(r"\d+", source):
            raise ValueError(f"{locale}: description structure or numeric claims differ from English")
    return plan


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def update(api, plan, output):
    versions = all_rows(api, f"/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200")
    version = next(v for v in versions if v["id"] == plan["version_id"])
    if (version["attributes"]["versionString"] != VERSION
            or version["attributes"]["appStoreState"] != "PREPARE_FOR_SUBMISSION"):
        raise ValueError("The approved App Store version is no longer editable")
    version_path = f"/appStoreVersions/{version['id']}?include=build"
    version_before = api.request("GET", version_path)["data"]
    path = f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=200"
    before = {row["attributes"]["locale"]: row for row in all_rows(api, path)}
    if digest(before["en-US"]["attributes"]["description"]) != digest(plan["english_description"]):
        raise ValueError("English description changed after translation; no upload performed")
    # Validate every target before making the first change. Existing keyword values
    # come only from the live snapshot; they are never included in a write request.
    for locale, text in plan["descriptions"].items():
        existing = digest(before[locale]["attributes"]["description"])
        if existing not in {plan["previous_description_sha256"][locale], digest(text)}:
            raise ValueError(f"{locale}: description changed after approval; no upload performed")
    output.mkdir(parents=True, exist_ok=True)
    save(output / "metadata-before.json", {"version": version_before, "localizations": before})
    for locale, text in plan["descriptions"].items():
        row = before[locale]
        if row["attributes"]["description"] != text:
            api.request("PATCH", f"/appStoreVersionLocalizations/{row['id']}", {
                "data": {"type": "appStoreVersionLocalizations", "id": row["id"],
                         "attributes": {"description": text}}})
        print(f"{locale}: description uploaded", flush=True)
    after = {row["attributes"]["locale"]: row for row in all_rows(api, path)}
    version_after = api.request("GET", version_path)["data"]
    save(output / "metadata-after.json", {"version": version_after, "localizations": after})
    if set(before) != set(after):
        raise ValueError("Unexpected storefront coverage change")
    for locale, row in before.items():
        expected = dict(row["attributes"])
        if locale in plan["descriptions"]:
            expected["description"] = plan["descriptions"][locale]
        if expected != after[locale]["attributes"]:
            raise ValueError(f"{locale}: unexpected listing change or description mismatch")
    if (version_before["attributes"] != version_after["attributes"]
            or version_before["relationships"]["build"] != version_after["relationships"]["build"]):
        raise ValueError("App Store version or selected build changed unexpectedly")
    receipt = {"app_id": APP_ID, "version": VERSION, "version_id": version["id"],
               "descriptions_verified": sorted(LOCALES),
               "keywords_unchanged_for_all_locales": True,
               "all_other_listing_attributes_unchanged": True,
               "selected_build_and_version_state_unchanged": True,
               "storefronts_verified": len(after),
               "description_sha256": {locale: digest(text) for locale, text in plan["descriptions"].items()}}
    save(output / "description-receipt.json", receipt)
    print("Verified all three descriptions; keywords and every other listing field are unchanged.", flush=True)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    plan = load_plan(args.plan)
    if args.validate_only:
        print("Verified three complete translations, matching English structure and numeric claims.")
        return
    update(client(), plan, args.output)


if __name__ == "__main__":
    main()
