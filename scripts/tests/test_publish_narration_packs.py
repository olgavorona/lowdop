import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import publish_narration_packs as publisher
import submit_narration_review as reviewer


class FakeApple:
    def __init__(self, existing=False, final_state="COMPLETE"):
        self.existing = existing
        self.final_state = final_state
        self.uploads = []

    def app_id(self):
        return "app"

    def asset_id(self, app_id, identifier):
        return identifier

    def upload_archive(self, app_id, identifier, archive, expected_version):
        self.uploads.append(identifier)
        return str(expected_version)

    def request(self, method, path):
        assert method == "GET"
        if path.startswith("/apps/"):
            return {"data": [{"id": "audio-sv", "attributes": {"assetPackIdentifier": "audio-sv"}}] if self.existing else []}
        if path.startswith("/backgroundAssets/"):
            return {"data": [{"id": "version-1", "attributes": {"version": "1", "state": "PROCESSING"}}]}
        if path.startswith("/backgroundAssetVersions/"):
            return {"data": {"id": "version-1", "attributes": {"version": "1", "state": self.final_state}}}
        raise AssertionError(path)


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.addCleanup(self.directory.cleanup)
        archive = self.root / "audio-sv.aar"
        archive.write_bytes(b"validated test archive")
        self.plan = {"packs": [{"identifier": "audio-sv", "version": 1,
                                "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}]}
        self.receipt = self.root / "receipt.json"

    def run_publisher(self, apple):
        plan_path = self.root / "plan.json"
        plan_path.write_text(json.dumps(self.plan))
        with patch.object(sys, "argv", ["publish", "--plan", str(plan_path), "--archives-dir", str(self.root),
                                        "--receipt", str(self.receipt)]), \
                patch.dict("os.environ", {"ASC_KEY_ID": "test", "ASC_ISSUER_ID": "test", "ASC_PRIVATE_KEY_PATH": "/unused"}), \
                patch.object(publisher, "make_token", return_value="fake-token") as token, \
                patch.object(publisher, "AppStoreConnect", return_value=apple):
            publisher.main()
            return token

    def test_changed_archive_is_rejected_before_authentication(self):
        (self.root / "audio-sv.aar").write_bytes(b"changed")
        apple = FakeApple()
        with self.assertRaisesRegex(ValueError, "checksum"):
            self.run_publisher(apple)
        self.assertEqual(apple.uploads, [])
        self.assertFalse(self.receipt.exists())

    def test_existing_version_prevents_duplicate_publication(self):
        apple = FakeApple(existing=True)
        with self.assertRaisesRegex(ValueError, "already has versions"):
            self.run_publisher(apple)
        self.assertEqual(apple.uploads, [])

    def test_success_receipt_records_completed_processing(self):
        apple = FakeApple()
        self.run_publisher(apple)
        receipt = json.loads(self.receipt.read_text())
        self.assertEqual(apple.uploads, ["audio-sv"])
        self.assertEqual(receipt["packs"][0]["attributes"]["state"], "COMPLETE")
        self.assertEqual(receipt["packs"][0]["sha256"], self.plan["packs"][0]["sha256"])

    def test_processing_failure_is_saved_and_reported(self):
        with self.assertRaisesRegex(RuntimeError, "Apple rejected"):
            self.run_publisher(FakeApple(final_state="FAILED"))
        self.assertEqual(json.loads(self.receipt.read_text())["packs"][0]["attributes"]["state"], "FAILED")


class FakeReviewApple:
    def __init__(self, foreign=False, unexpected_binary=False):
        self.foreign = foreign
        self.unexpected_binary = unexpected_binary
        self.writes = []
        self.items = []

    def app_id(self):
        return "app"

    def request(self, method, path, body=None):
        if method != "GET":
            self.writes.append((method, path))
        if path.startswith("/apps/"):
            return {"data": [{"id": "asset-sv", "attributes": {"assetPackIdentifier": "audio-sv"}}]}
        if path.startswith("/backgroundAssetVersions/"):
            return {"data": {"attributes": {"state": "COMPLETE", "version": "1"},
                             "relationships": {"backgroundAsset": {"data": {"id": "wrong" if self.foreign else "asset-sv"}}}}}
        if method == "POST" and path == "/reviewSubmissions":
            return {"data": {"id": "review", "attributes": {"state": "READY_FOR_REVIEW"}}}
        if method == "POST" and path == "/reviewSubmissionItems":
            item = {"id": "item", "relationships": body["data"]["relationships"]}
            self.items.append(item)
            return {"data": item}
        if method == "GET" and path.startswith("/reviewSubmissions/review/items"):
            if self.unexpected_binary:
                return {"data": self.items + [{"id": "binary", "relationships": {"appStoreVersion": {"data": {"id": "unrelated"}}}}]}
            return {"data": self.items}
        if method == "PATCH" and path == "/reviewSubmissions/review":
            return {"data": {"id": "review", "attributes": {"state": "WAITING_FOR_REVIEW"}}}
        raise AssertionError((method, path))


class ReviewSubmissionTests(unittest.TestCase):
    def run_review(self, apple, root):
        publication = root / "publication.json"
        publication.write_text(json.dumps({"app_id": "app", "packs": [
            {"identifier": "audio-sv", "version": 1, "version_id": "version-sv", "asset_id": "asset-sv"}]}))
        output = root / "review.json"
        with patch.object(sys, "argv", ["review", "--publication-receipt", str(publication), "--receipt", str(output)]), \
                patch.dict("os.environ", {"ASC_KEY_ID": "test", "ASC_ISSUER_ID": "test", "ASC_PRIVATE_KEY_PATH": "/unused"}), \
                patch.object(reviewer, "make_token", return_value="fake-token"), \
                patch.object(reviewer, "AppStoreConnect", return_value=apple):
            reviewer.main()
        return json.loads(output.read_text())

    def test_foreign_asset_is_rejected_before_remote_mutation(self):
        apple = FakeReviewApple(foreign=True)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "does not belong"):
                self.run_review(apple, Path(directory))
        self.assertEqual(apple.writes, [])

    def test_unexpected_app_binary_prevents_submission(self):
        apple = FakeReviewApple(unexpected_binary=True)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "do not exactly match"):
                self.run_review(apple, Path(directory))
        self.assertFalse(any(method == "PATCH" for method, path in apple.writes))

    def test_only_approved_versions_are_submitted(self):
        apple = FakeReviewApple()
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_review(apple, Path(directory))
        self.assertEqual(result["submission"]["attributes"]["state"], "WAITING_FOR_REVIEW")
        self.assertEqual(apple.writes[-1], ("PATCH", "/reviewSubmissions/review"))
        self.assertEqual(result["items"][0]["relationships"]["backgroundAssetVersion"]["data"]["id"], "version-sv")


if __name__ == "__main__":
    unittest.main()
