#!/usr/bin/env python3
"""Submit the verified release build for review and hold public release manually."""

import argparse
import json
from pathlib import Path

from publish_app_store_build import all_rows, client, validate_package


def item_version_id(item: dict) -> str | None:
    return (item.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id")


def validate_submission_items(items: list, version_id: str) -> None:
    if len(items) != 1 or item_version_id(items[0]) != version_id:
        raise ValueError("Review submission must contain exactly the requested app version")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--release-receipt", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    args = parser.parse_args()
    plan, metadata, _ = validate_package(args.package)
    if not plan.get("submit_for_review", False):
        print("Review submission was not requested in this release plan.")
        return
    release = json.loads(args.release_receipt.read_text())
    for field in ("version", "build_number"):
        if release[field] != plan[field]:
            raise ValueError("The upload receipt does not match the release plan")
    if release["processing_state"] != "VALID" or release["ipa_sha256"] != plan["sha256"] or release["metadata_sha256"] != plan["metadata_sha256"]:
        raise ValueError("The upload receipt is not for this verified package")
    api = client()
    app = api.app_id()
    if app != release["app_id"]:
        raise ValueError("The upload receipt belongs to another app")
    version_id = release["version_id"]
    version = api.request("GET", f"/appStoreVersions/{version_id}")["data"]
    build = api.request("GET", f"/appStoreVersions/{version_id}/build")["data"]
    if version["attributes"]["versionString"] != plan["version"] or build["id"] != release["build_id"] or build["attributes"]["processingState"] != "VALID":
        raise ValueError("The selected App Store build no longer matches the verified upload")
    localizations = all_rows(api, f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=200")
    actual = {row["attributes"]["locale"]: row["attributes"] for row in localizations}
    if set(actual) != set(metadata["localizations"]):
        raise ValueError("Storefront localization coverage changed after upload")
    for locale, values in metadata["localizations"].items():
        if any(actual[locale][field] != values[field] for field in ("whatsNew", "promotionalText")):
            raise ValueError(f"{locale}: release text changed after upload")
    state = version["attributes"]["appStoreState"]
    if state not in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"}:
        raise ValueError(f"App Store version cannot be submitted from state {state}")
    report = {"app_id": app, "version": plan["version"], "build_number": plan["build_number"],
              "version_id": version_id, "build_id": build["id"]}

    def save() -> None:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(report, indent=2) + "\n")

    if state in {"WAITING_FOR_REVIEW", "IN_REVIEW"}:
        if version["attributes"]["releaseType"] != "MANUAL":
            raise ValueError("An existing submission is not held for manual release")
        report["app_store_state"] = state
        report["release_type"] = "MANUAL"
        save()
        print(f"The verified build is already {state}.")
        return
    # Review authorization does not authorize publishing the app automatically.
    api.request("PATCH", f"/appStoreVersions/{version_id}", {"data": {
        "type": "appStoreVersions", "id": version_id, "attributes": {"releaseType": "MANUAL"}}})
    submissions = all_rows(api, f"/apps/{app}/reviewSubmissions?limit=200")
    matching = []
    for submission in submissions:
        if submission["attributes"]["state"] == "COMPLETE":
            continue
        items = all_rows(api, f"/reviewSubmissions/{submission['id']}/items?include=appStoreVersion&limit=200")
        if any(item_version_id(item) == version_id for item in items):
            validate_submission_items(items, version_id)
            matching.append(submission)
    if len(matching) > 1:
        raise ValueError("Multiple review submissions contain the requested app version")
    if matching:
        submission = matching[0]
    else:
        submission = api.request("POST", "/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app}}}}})["data"]
        report["submission_id"] = submission["id"]
        save()
        api.request("POST", "/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems", "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
    report["submission_id"] = submission["id"]
    save()
    items = all_rows(api, f"/reviewSubmissions/{submission['id']}/items?include=appStoreVersion&limit=200")
    validate_submission_items(items, version_id)
    report["items"] = items
    save()
    submitted = api.request("PATCH", f"/reviewSubmissions/{submission['id']}", {"data": {
        "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True}}})["data"]
    version = api.request("GET", f"/appStoreVersions/{version_id}")["data"]
    report.update({"submission": submitted, "app_store_state": version["attributes"]["appStoreState"],
                   "release_type": version["attributes"]["releaseType"]})
    save()
    if submitted["attributes"]["state"] not in {"WAITING_FOR_REVIEW", "IN_REVIEW"} or report["release_type"] != "MANUAL":
        raise ValueError("Apple did not confirm the expected review state and manual release")
    print(f"Submitted {plan['version']} ({plan['build_number']}) for review: {report['app_store_state']}. Public release is manual.")


if __name__ == "__main__":
    main()
