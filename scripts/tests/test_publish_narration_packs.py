import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import publish_narration_packs as publisher


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


if __name__ == "__main__":
    unittest.main()
