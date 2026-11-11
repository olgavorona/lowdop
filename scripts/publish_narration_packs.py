#!/usr/bin/env python3
"""Publish checksum-verified narration archives and save Apple's processing receipt."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import time

from upload_background_assets import AppStoreConnect, make_token


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--archives-dir", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--wait-seconds", type=int, default=900)
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text())
    packs = plan["packs"]
    if not packs or len({p["identifier"] for p in packs}) != len(packs):
        raise ValueError("The publication plan must contain unique asset packs")
    for pack in packs:
        if pack["identifier"] not in {f"audio-{locale}" for locale in ("de", "es", "ja", "zh-Hans", "ko", "ar", "sv", "fi", "nl")}:
            raise ValueError("Unsupported asset pack identifier")
        name = pack["identifier"] + ".aar"
        archive = args.archives_dir / name
        if hashlib.sha256(archive.read_bytes()).hexdigest() != pack["sha256"]:
            raise ValueError(f"Archive checksum does not match approved plan: {name}")

    def client() -> AppStoreConnect:
        return AppStoreConnect(make_token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"],
                                         Path(os.environ["ASC_PRIVATE_KEY_PATH"]).expanduser()))

    api = client()
    app_id = api.app_id()
    receipt = {"app_id": app_id, "created_at": datetime.now(timezone.utc).isoformat(), "packs": []}

    def save() -> None:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n")

    save()
    # Refuse to create another version if any requested pack already has versions.
    # A retry must inspect the saved receipt before proposing another publication.
    assets = api.request("GET", f"/apps/{app_id}/backgroundAssets?limit=200")["data"]
    for asset in assets:
        if asset["attributes"]["assetPackIdentifier"] in {p["identifier"] for p in packs}:
            versions = api.request("GET", f"/backgroundAssets/{asset['id']}/versions?limit=200")["data"]
            if versions:
                raise ValueError(f"{asset['attributes']['assetPackIdentifier']} already has versions; inspect them before retrying")

    for pack in packs:
        api = client()
        archive = args.archives_dir / (pack["identifier"] + ".aar")
        number = api.upload_archive(app_id, pack["identifier"], archive, expected_version=pack["version"])
        asset_id = api.asset_id(app_id, pack["identifier"])
        versions = api.request("GET", f"/backgroundAssets/{asset_id}/versions?limit=200")["data"]
        version = next(v for v in versions if str(v["attributes"]["version"]) == number)
        receipt["packs"].append({**pack, "asset_id": asset_id, "version_id": version["id"],
                                 "bytes": archive.stat().st_size, "attributes": version["attributes"]})
        save()
        print(f"Submitted {pack['identifier']} version {number}", flush=True)

    deadline = time.monotonic() + args.wait_seconds
    while True:
        for pack in receipt["packs"]:
            if pack["attributes"].get("state") == "COMPLETE":
                continue
            version = client().request("GET", f"/backgroundAssetVersions/{pack['version_id']}")["data"]
            pack["attributes"] = version["attributes"]
            print(f"{pack['identifier']}: {pack['attributes'].get('state')}", flush=True)
        save()
        states = {p["attributes"].get("state") for p in receipt["packs"]}
        if "FAILED" in states:
            raise RuntimeError("Apple rejected an archive; see the receipt's stateDetails")
        if states == {"COMPLETE"}:
            print("All narration packs finished Apple processing.", flush=True)
            return
        if time.monotonic() >= deadline:
            raise TimeoutError("Apple processing is still pending; inspect the saved receipt before retrying")
        time.sleep(15)


if __name__ == "__main__":
    main()
