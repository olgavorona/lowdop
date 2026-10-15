#!/usr/bin/env python3
"""Upload Apple-hosted Background Asset archives using App Store Connect API."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / "fastlane" / ".env"
API_ROOT = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.lowdopamine.labyrinth"


def make_ssl_context() -> ssl.SSLContext:
    verify_paths = ssl.get_default_verify_paths()
    cafile = os.environ.get("SSL_CERT_FILE") or verify_paths.cafile
    if not cafile or not Path(cafile).is_file():
        system_bundle = Path("/etc/ssl/cert.pem")
        cafile = str(system_bundle) if system_bundle.is_file() else None
    return ssl.create_default_context(cafile=cafile)


SSL_CONTEXT = make_ssl_context()


def load_local_env() -> None:
    if not ENV_FILE.exists():
        return
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key, value = key.strip(), value.strip().strip("\"'")
        if key and key not in os.environ:
            os.environ[key] = value


def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def der_ecdsa_to_raw(signature: bytes) -> bytes:
    """Convert OpenSSL's ASN.1 DER ECDSA signature to JWT ES256 r||s form."""
    if len(signature) < 8 or signature[0] != 0x30:
        raise ValueError("OpenSSL returned an invalid ECDSA signature")
    cursor = 2
    if signature[1] & 0x80:
        length_bytes = signature[1] & 0x7F
        cursor = 2 + length_bytes
    if signature[cursor] != 0x02:
        raise ValueError("Invalid ECDSA r integer")
    r_length = signature[cursor + 1]
    r = signature[cursor + 2 : cursor + 2 + r_length]
    cursor += 2 + r_length
    if signature[cursor] != 0x02:
        raise ValueError("Invalid ECDSA s integer")
    s_length = signature[cursor + 1]
    s = signature[cursor + 2 : cursor + 2 + s_length]
    r = r.lstrip(b"\x00").rjust(32, b"\x00")
    s = s.lstrip(b"\x00").rjust(32, b"\x00")
    if len(r) != 32 or len(s) != 32:
        raise ValueError("ECDSA signature is not P-256")
    return r + s


def make_token(key_id: str, issuer_id: str, key_path: Path) -> str:
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header, separators=(',', ':')).encode())}.{b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    result = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(key_path), "-binary"],
        input=signing_input.encode("ascii"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        raise RuntimeError("OpenSSL could not sign the App Store Connect token: " + result.stderr.decode(errors="replace").strip())
    return signing_input + "." + b64url(der_ecdsa_to_raw(result.stdout))


class AppStoreConnect:
    def __init__(self, token: str):
        self.token = token

    def request(self, method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
        url = path if path.startswith("https://") else API_ROOT + path
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={"Authorization": f"Bearer {self.token}", "Accept": "application/json", **({"Content-Type": "application/json"} if body is not None else {})},
        )
        try:
            with urllib.request.urlopen(request, timeout=90, context=SSL_CONTEXT) as response:
                raw = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"App Store Connect API {method} {url} returned HTTP {error.code}: {detail}") from error
        except urllib.error.URLError as error:
            raise RuntimeError(f"App Store Connect API request failed: {error.reason}") from error
        return json.loads(raw) if raw else {}

    def app_id(self) -> str:
        configured = os.environ.get("ASC_APP_ID")
        if configured:
            return configured
        query = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID})
        response = self.request("GET", f"/apps?{query}")
        apps = response.get("data", [])
        if not apps:
            raise RuntimeError(f"No App Store Connect app found for bundle ID {BUNDLE_ID}")
        return apps[0]["id"]

    def asset_id(self, app_id: str, identifier: str) -> str:
        query = urllib.parse.urlencode({"limit": "200"})
        response = self.request("GET", f"/apps/{app_id}/backgroundAssets?{query}")
        for item in response.get("data", []):
            if item.get("attributes", {}).get("assetPackIdentifier") == identifier:
                return item["id"]
        response = self.request(
            "POST",
            "/backgroundAssets",
            {
                "data": {
                    "type": "backgroundAssets",
                    "attributes": {"assetPackIdentifier": identifier},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )
        return response["data"]["id"]

    def upload_archive(self, app_id: str, identifier: str, archive: Path) -> str:
        asset_id = self.asset_id(app_id, identifier)
        version = self.request(
            "POST",
            "/backgroundAssetVersions",
            {
                "data": {
                    "type": "backgroundAssetVersions",
                    "relationships": {"backgroundAsset": {"data": {"type": "backgroundAssets", "id": asset_id}}},
                }
            },
        )["data"]
        version_id = version["id"]
        version_number = version.get("attributes", {}).get("version", "pending")

        reservation = self.request(
            "POST",
            "/backgroundAssetUploadFiles",
            {
                "data": {
                    "type": "backgroundAssetUploadFiles",
                    "attributes": {"assetType": "ASSET", "fileName": archive.name, "fileSize": archive.stat().st_size},
                    "relationships": {"backgroundAssetVersion": {"data": {"type": "backgroundAssetVersions", "id": version_id}}},
                }
            },
        )["data"]
        upload_id = reservation["id"]
        operations = reservation.get("attributes", {}).get("uploadOperations", [])
        if not operations:
            raise RuntimeError(f"Apple returned no upload operations for {identifier}")

        with archive.open("rb") as file:
            for operation in sorted(operations, key=lambda op: op.get("offset", 0)):
                offset, length = int(operation["offset"]), int(operation["length"])
                file.seek(offset)
                chunk = file.read(length)
                if len(chunk) != length:
                    raise RuntimeError(f"Unexpected short read uploading {archive.name}")
                headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
                request = urllib.request.Request(operation["url"], data=chunk, method=operation.get("method", "PUT"), headers=headers)
                try:
                    with urllib.request.urlopen(request, timeout=300, context=SSL_CONTEXT) as response:
                        response.read()
                except urllib.error.HTTPError as error:
                    detail = error.read().decode("utf-8", errors="replace")
                    raise RuntimeError(f"Asset part upload failed (HTTP {error.code}): {detail}") from error
                print(f"  uploaded {min(offset + length, archive.stat().st_size):,}/{archive.stat().st_size:,} bytes")

        checksum = hashlib.md5(archive.read_bytes()).hexdigest()
        self.request(
            "PATCH",
            f"/backgroundAssetUploadFiles/{upload_id}",
            {
                "data": {
                    "type": "backgroundAssetUploadFiles",
                    "id": upload_id,
                    "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
                }
            },
        )
        return str(version_number)


def main() -> int:
    load_local_env()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, nargs="+", help="One or more .aar files")
    args = parser.parse_args()

    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_path_value = os.environ.get("ASC_PRIVATE_KEY_PATH")
    if not key_id or not issuer_id or not key_path_value:
        parser.error("Set ASC_KEY_ID, ASC_ISSUER_ID, and ASC_PRIVATE_KEY_PATH in fastlane/.env")
    key_path = Path(key_path_value).expanduser()
    if not key_path.is_file():
        parser.error(f"App Store Connect private key file not found: {key_path}")

    archives: list[tuple[str, Path]] = []
    for path_value in args.archive:
        path = path_value.expanduser().resolve()
        match = re.fullmatch(r"audio-(de|es)\.aar", path.name)
        if not match or not path.is_file():
            parser.error(f"Expected an existing audio-de.aar or audio-es.aar archive, got: {path}")
        archives.append((f"audio-{match.group(1)}", path))

    try:
        client = AppStoreConnect(make_token(key_id, issuer_id, key_path))
        app_id = client.app_id()
        for identifier, archive in archives:
            print(f"Uploading {identifier} from {archive}…")
            version = client.upload_archive(app_id, identifier, archive)
            print(f"Submitted {identifier} version {version} for Apple processing.")
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Upload failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
