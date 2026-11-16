import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import submit_app_review


class ReviewAPI:
    def __init__(self, selected_build="b", state="PREPARE_FOR_SUBMISSION", release_type="AFTER_APPROVAL"):
        self.selected_build = selected_build
        self.state = state
        self.release_type = release_type
        self.mutations = []
        self.items = []

    def app_id(self):
        return "app"

    def request(self, method, path, body=None):
        if method != "GET":
            self.mutations.append((method, path, body))
        if path == "/appStoreVersions/v":
            if method == "PATCH":
                self.release_type = body["data"]["attributes"]["releaseType"]
            return {"data": {"attributes": {"versionString": "1.5.5", "appStoreState": self.state, "releaseType": self.release_type}}}
        if path == "/appStoreVersions/v/build":
            return {"data": {"id": self.selected_build, "attributes": {"processingState": "VALID"}}}
        if "appStoreVersionLocalizations" in path:
            return {"data": [{"attributes": {"locale": "en-US", "whatsNew": "Notes", "promotionalText": "Promo"}}]}
        if path.startswith("/apps/app/reviewSubmissions"):
            return {"data": []}
        if path == "/reviewSubmissions":
            return {"data": {"id": "s", "attributes": {"state": "READY_FOR_REVIEW"}}}
        if path == "/reviewSubmissionItems":
            self.items.append(body["data"])
            return {"data": body["data"]}
        if path.startswith("/reviewSubmissions/s/items"):
            return {"data": self.items}
        if path == "/reviewSubmissions/s" and method == "PATCH":
            self.state = "WAITING_FOR_REVIEW"
            return {"data": {"id": "s", "attributes": {"state": self.state}}}
        raise AssertionError((method, path))


class SubmitReviewTests(unittest.TestCase):
    def run_submission(self, api, folder):
        receipt = {"version": "1.5.5", "build_number": "8", "processing_state": "VALID", "app_id": "app",
                   "version_id": "v", "build_id": "b", "ipa_sha256": "ipa", "metadata_sha256": "text"}
        source = folder / "upload.json"
        source.write_text(json.dumps(receipt))
        plan = {"version": "1.5.5", "build_number": "8", "submit_for_review": True, "sha256": "ipa", "metadata_sha256": "text"}
        metadata = {"localizations": {"en-US": {"whatsNew": "Notes", "promotionalText": "Promo"}}}
        output = folder / "review.json"
        with patch.object(submit_app_review, "client", return_value=api), patch.object(submit_app_review, "validate_package", return_value=(plan, metadata, folder / "app.ipa")), patch.object(sys, "argv", ["submit", "--package", str(folder), "--release-receipt", str(source), "--receipt", str(output)]):
            submit_app_review.main()
        return json.loads(output.read_text())

    def test_submits_only_selected_version_and_holds_public_release(self):
        api = ReviewAPI()
        with tempfile.TemporaryDirectory() as folder:
            receipt = self.run_submission(api, Path(folder))
        self.assertEqual(receipt["app_store_state"], "WAITING_FOR_REVIEW")
        self.assertEqual(receipt["release_type"], "MANUAL")
        self.assertEqual(api.mutations[0][1], "/appStoreVersions/v")
        self.assertEqual(len(api.items), 1)
        self.assertEqual(api.items[0]["relationships"]["appStoreVersion"]["data"]["id"], "v")

    def test_changed_selected_build_prevents_all_mutations(self):
        api = ReviewAPI(selected_build="unexpected")
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(ValueError):
            self.run_submission(api, Path(folder))
        self.assertEqual(api.mutations, [])

    def test_existing_review_is_not_submitted_twice(self):
        api = ReviewAPI(state="WAITING_FOR_REVIEW", release_type="MANUAL")
        with tempfile.TemporaryDirectory() as folder:
            self.run_submission(api, Path(folder))
        self.assertEqual(api.mutations, [])

    def test_unrelated_or_duplicate_review_items_are_rejected(self):
        valid = {"relationships": {"appStoreVersion": {"data": {"id": "v"}}}}
        for items in ([], [valid, valid], [{"relationships": {"backgroundAssetVersion": {"data": {"id": "v"}}}}], [{"relationships": {"appStoreVersion": {"data": None}}}]):
            with self.subTest(items=items), self.assertRaises(ValueError):
                submit_app_review.validate_submission_items(items, "v")


if __name__ == "__main__":
    unittest.main()
