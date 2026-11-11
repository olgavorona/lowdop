#!/usr/bin/env python3
"""Upload a verified IPA and localized release text without submitting app review."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time
import urllib.parse
import zipfile

from upload_background_assets import AppStoreConnect, make_token

BUNDLE_ID = "com.lowdopamine.labyrinth"


def validate_package(folder: Path) -> tuple[dict, dict, Path]:
    plan = json.loads((folder / "release-plan.json").read_text())
    if plan["bundle_id"] != BUNDLE_ID:
        raise ValueError("Release plan targets a different app")
    for field in ("ipa", "metadata"):
        if Path(plan[field]).name != plan[field]:
            raise ValueError("Release filenames must not contain directory components")
    ipa = folder / plan["ipa"]
    metadata_path = folder / plan["metadata"]
    if hashlib.sha256(ipa.read_bytes()).hexdigest() != plan["sha256"]:
        raise ValueError("IPA checksum does not match the release plan")
    if hashlib.sha256(metadata_path.read_bytes()).hexdigest() != plan["metadata_sha256"]:
        raise ValueError("Metadata checksum does not match the release plan")
    metadata = json.loads(metadata_path.read_text())
    if (metadata["version"], metadata["build_number"]) != (plan["version"], plan["build_number"]):
        raise ValueError("Metadata version does not match the IPA release plan")
    if set(metadata["localizations"]) != set(plan["locales"]):
        raise ValueError("Release locale coverage does not match the plan")
    for locale, values in metadata["localizations"].items():
        if not 0 < len(values["whatsNew"]) <= 4000 or not 0 < len(values["promotionalText"]) <= 170:
            raise ValueError(f"{locale}: invalid release text length")
    for locale, values in metadata.get("new_localizations", {}).items():
        if locale not in metadata["localizations"]:
            raise ValueError("A new storefront is missing release text")
        if not 0 < len(values["name"]) <= 30 or not 0 < len(values["subtitle"]) <= 30:
            raise ValueError(f"{locale}: invalid localized app information")
        if not 0 < len(values["description"]) <= 4000 or not 0 < len(values["keywords"].encode()) <= 100:
            raise ValueError(f"{locale}: invalid description or keywords")
    with zipfile.ZipFile(ipa) as archive:
        infos = [name for name in archive.namelist() if name.startswith("Payload/")
                 and name.endswith(".app/Info.plist") and name.count("/") == 2]
        if len(infos) != 1:
            raise ValueError("Expected exactly one app in the IPA")
        info = plistlib.loads(archive.read(infos[0]))
        if info["CFBundleIdentifier"] != BUNDLE_ID:
            raise ValueError("IPA bundle identifier does not match the release plan")
        for name in infos + [n for n in archive.namelist() if n.endswith(".appex/Info.plist")]:
            current = plistlib.loads(archive.read(name))
            if (current["CFBundleShortVersionString"], current["CFBundleVersion"]) != (plan["version"], plan["build_number"]):
                raise ValueError("IPA app and extension versions do not match the release plan")
    return plan, metadata, ipa


def client() -> AppStoreConnect:
    return AppStoreConnect(make_token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"],
                                     Path(os.environ["ASC_PRIVATE_KEY_PATH"]).expanduser()))


def all_rows(api: AppStoreConnect, path: str) -> list:
    rows = []
    while path:
        response = api.request("GET", path)
        rows.extend(response.get("data", []))
        path = response.get("links", {}).get("next")
    return rows


def update_metadata(api: AppStoreConnect, app: str, metadata: dict, output: Path) -> str:
    versions = all_rows(api, f"/apps/{app}/appStoreVersions?filter[platform]=IOS&limit=200")
    version = next(v for v in versions if v["attributes"]["versionString"] == metadata["version"])
    if version["attributes"]["appStoreState"] != "PREPARE_FOR_SUBMISSION":
        raise ValueError("The requested App Store version is no longer editable; no listing changes made")
    version_id = version["id"]
    path = f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=200"
    original = {r["attributes"]["locale"]: r for r in all_rows(api, path)}
    if not set(original) <= set(metadata["localizations"]):
        raise ValueError("An existing storefront locale is missing translated release text")
    infos = all_rows(api, f"/apps/{app}/appInfos?limit=200")
    info = next(i for i in infos if i["attributes"]["appStoreState"] == "PREPARE_FOR_SUBMISSION")
    info_path = f"/appInfos/{info['id']}/appInfoLocalizations?limit=200"
    original_info = {r["attributes"]["locale"]: r for r in all_rows(api, info_path)}
    output.mkdir(parents=True, exist_ok=True)
    (output / "metadata-before.json").write_text(json.dumps({"version": version, "localizations": original,
                                                            "app_info": info, "app_info_localizations": original_info}, ensure_ascii=False, indent=2) + "\n")
    reference_info = original_info["en-US"]["attributes"]
    reference = original["en-US"]["attributes"]
    for locale, text in metadata.get("new_localizations", {}).items():
        if locale not in original_info:
            attributes = {"locale": locale, "name": text["name"], "subtitle": text["subtitle"],
                          "privacyPolicyUrl": reference_info["privacyPolicyUrl"]}
            api.request("POST", "/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": attributes,
                        "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
    # Creating an app-info localization may also create version-localization records.
    current = {r["attributes"]["locale"]: r for r in all_rows(api, path)}
    for locale, text in metadata["localizations"].items():
        attributes = {"whatsNew": text["whatsNew"], "promotionalText": text["promotionalText"]}
        if locale not in original and locale in metadata.get("new_localizations", {}):
            new = metadata["new_localizations"][locale]
            attributes.update({"description": new["description"], "keywords": new["keywords"],
                               "supportUrl": reference["supportUrl"], "marketingUrl": reference["marketingUrl"]})
        if locale in current:
            row = current[locale]
            api.request("PATCH", f"/appStoreVersionLocalizations/{row['id']}", {"data": {
                "type": "appStoreVersionLocalizations", "id": row["id"], "attributes": attributes}})
        else:
            api.request("POST", "/appStoreVersionLocalizations", {"data": {
                "type": "appStoreVersionLocalizations", "attributes": {"locale": locale, **attributes},
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
        print(f"{locale}: uploaded What's New and promotional text", flush=True)
    after = {r["attributes"]["locale"]: r for r in all_rows(api, path)}
    if set(after) != set(metadata["localizations"]):
        raise ValueError("Uploaded storefront locales do not match the release plan")
    for locale, text in metadata["localizations"].items():
        if any(after[locale]["attributes"][field] != text[field] for field in ("whatsNew", "promotionalText")):
            raise ValueError(f"{locale}: uploaded text does not match the prepared translation")
        if locale in original:
            for field, value in original[locale]["attributes"].items():
                if field not in {"whatsNew", "promotionalText"} and after[locale]["attributes"].get(field) != value:
                    raise ValueError(f"{locale}: unrelated listing field changed: {field}")
    after_info = {r["attributes"]["locale"]: r for r in all_rows(api, info_path)}
    if any(after_info[locale]["attributes"] != row["attributes"] for locale, row in original_info.items()):
        raise ValueError("Existing app names, subtitles, or privacy information changed unexpectedly")
    (output / "metadata-after.json").write_text(json.dumps({"version_id": version_id, "localizations": after,
                                                           "app_info_localizations": after_info}, ensure_ascii=False, indent=2) + "\n")
    return version_id


def find_build(api: AppStoreConnect, app: str, plan: dict) -> dict | None:
    query = urllib.parse.urlencode({"filter[app]": app, "filter[version]": plan["build_number"],
                                   "filter[preReleaseVersion.version]": plan["version"], "limit": 200})
    rows = all_rows(api, "/builds?" + query)
    if len(rows) > 1:
        raise ValueError("Apple returned multiple matching builds")
    return rows[0] if rows else None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--wait-seconds", type=int, default=1800)
    args = parser.parse_args()
    plan, metadata, ipa = validate_package(args.package)
    print(f"Verified version {plan['version']} build {plan['build_number']} and {len(metadata['localizations'])} localized listings", flush=True)
    if args.validate_only:
        return
    api = client()
    app = api.app_id()
    version_id = update_metadata(api, app, metadata, args.output)
    build = find_build(api, app, plan)
    if build is None:
        # Upload only through the GitHub Actions runner; signing credentials stay on the build Mac.
        subprocess.run(["xcrun", "altool", "--upload-app", "-f", str(ipa), "--type", "ios",
                        "--apiKey", os.environ["ASC_KEY_ID"], "--apiIssuer", os.environ["ASC_ISSUER_ID"],
                        "--output-format", "json"], check=True)
    deadline = time.monotonic() + args.wait_seconds
    while True:
        api = client()
        build = find_build(api, app, plan)
        state = build["attributes"]["processingState"] if build else "AWAITING_PROCESSING"
        print(f"Build {plan['version']} ({plan['build_number']}): {state}", flush=True)
        if state == "VALID":
            break
        if state in {"FAILED", "INVALID"}:
            raise RuntimeError(f"Apple build processing failed: {state}")
        if time.monotonic() >= deadline:
            raise TimeoutError("Build processing is still pending; inspect Apple status before retrying")
        time.sleep(15)
    if build["attributes"].get("usesNonExemptEncryption") is None:
        # The app uses Apple's standard HTTPS frameworks and no non-exempt encryption.
        api.request("PATCH", f"/builds/{build['id']}", {"data": {"type": "builds", "id": build["id"],
                    "attributes": {"usesNonExemptEncryption": False}}})
    api.request("PATCH", f"/appStoreVersions/{version_id}/relationships/build", {
        "data": {"type": "builds", "id": build["id"]}})
    selected = api.request("GET", f"/appStoreVersions/{version_id}/build")["data"]
    version = api.request("GET", f"/appStoreVersions/{version_id}")["data"]
    if selected["id"] != build["id"] or version["attributes"]["appStoreState"] != "PREPARE_FOR_SUBMISSION":
        raise ValueError("Final build selection or app release state did not match the requested upload")
    receipt = {"app_id": app, "version": plan["version"], "build_number": plan["build_number"],
               "build_id": build["id"], "processing_state": "VALID", "version_id": version_id,
               "app_store_state": version["attributes"]["appStoreState"],
               "localized_fields_verified": 2 * len(metadata["localizations"]), "locales": sorted(metadata["localizations"]),
               "ipa_sha256": plan["sha256"], "metadata_sha256": plan["metadata_sha256"]}
    (args.output / "release-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("Build processed, selected for the App Store version, and all localized release text verified.", flush=True)


if __name__ == "__main__":
    main()
