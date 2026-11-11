#!/usr/bin/env python3
"""Submit only the processed narration versions in a CI receipt to App Store review."""

import argparse
import json
import os
from pathlib import Path

from upload_background_assets import AppStoreConnect, make_token


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publication-receipt", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    args = parser.parse_args()
    publication = json.loads(args.publication_receipt.read_text())
    packs = publication["packs"]
    if not packs or len({p["version_id"] for p in packs}) != len(packs):
        raise ValueError("Expected unique narration pack versions")
    if any(p["identifier"] not in {f"audio-{locale}" for locale in ("de", "es", "ja", "zh-Hans", "ko", "ar", "sv", "fi", "nl")} for p in packs):
        raise ValueError("The receipt contains an unsupported narration identifier")
    api = AppStoreConnect(make_token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"],
                                     Path(os.environ["ASC_PRIVATE_KEY_PATH"]).expanduser()))
    app_id = api.app_id()
    if app_id != publication["app_id"]:
        raise ValueError("The publication receipt is for a different app")
    assets = {asset["id"]: asset["attributes"]["assetPackIdentifier"]
              for asset in api.request("GET", f"/apps/{app_id}/backgroundAssets?limit=200")["data"]}
    for pack in packs:
        version = api.request("GET", f"/backgroundAssetVersions/{pack['version_id']}?include=backgroundAsset")["data"]
        parent = version["relationships"]["backgroundAsset"]["data"]["id"]
        if parent != pack["asset_id"] or assets.get(parent) != pack["identifier"]:
            raise ValueError("A version does not belong to the expected app and narration pack")
        if version["attributes"]["state"] != "COMPLETE" or str(version["attributes"]["version"]) != str(pack["version"]):
            raise ValueError("A narration version is not fully processed or has changed")

    submission = api.request("POST", "/reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}
    }})["data"]
    report = {"app_id": app_id, "submission_id": submission["id"], "packs": packs, "submission": submission, "items": []}

    def save() -> None:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(report, indent=2) + "\n")

    save()
    for pack in packs:
        item = api.request("POST", "/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems", "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                "backgroundAssetVersion": {"data": {"type": "backgroundAssetVersions", "id": pack["version_id"]}}
            }
        }})["data"]
        report["items"].append(item)
        save()
    # Re-read the server's submission and verify its exact scope before submitting it.
    items = api.request("GET", f"/reviewSubmissions/{submission['id']}/items?include=backgroundAssetVersion&limit=200")["data"]
    expected = {pack["version_id"] for pack in packs}
    actual = {item.get("relationships", {}).get("backgroundAssetVersion", {}).get("data", {}).get("id") for item in items}
    if len(items) != len(packs) or actual != expected:
        raise ValueError("Review submission items do not exactly match the approved narration versions")
    if any(item.get("relationships", {}).get("appStoreVersion", {}).get("data") for item in items):
        raise ValueError("An app binary was unexpectedly included; refusing to submit")
    submitted = api.request("PATCH", f"/reviewSubmissions/{submission['id']}", {"data": {
        "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True}
    }})["data"]
    report["submission"] = submitted
    report["items"] = items
    save()
    print(f"Submitted {len(packs)} narration packs for App Store review: {submitted['attributes']['state']}", flush=True)


if __name__ == "__main__":
    main()
