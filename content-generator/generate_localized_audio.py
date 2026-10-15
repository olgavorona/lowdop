#!/usr/bin/env python3
"""Generate localized app narration from a translated JSON file using ElevenLabs."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import requests


ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / "content-generator/localized-audio"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("locale", choices=("de", "es"))
    args = parser.parse_args()

    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        raise SystemExit("ELEVENLABS_API_KEY is not set")
    voice_id = os.environ.get("ELEVENLABS_VOICE_ID", "XB0fDUnXU5powFXDhCwa")
    scripts_path = PACKS / f"narration-{args.locale}.json"
    if not scripts_path.exists():
        raise SystemExit(f"Translate narration-{args.locale}-template.json to {scripts_path.name} first")

    scripts = json.loads(scripts_path.read_text())
    if not scripts or any(not isinstance(text, str) or not text.strip() for text in scripts.values()):
        raise SystemExit(f"{scripts_path.name} must contain non-empty translated strings")

    output = PACKS / args.locale / "audio"
    output.mkdir(parents=True, exist_ok=True)
    endpoint = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    headers = {"xi-api-key": api_key, "Content-Type": "application/json", "Accept": "audio/mpeg"}
    for key, text in scripts.items():
        destination = output / f"{key}.mp3"
        if destination.exists():
            print(f"Skipping {destination.name} (already exists)", flush=True)
            continue
        response = requests.post(
            endpoint,
            headers=headers,
            json={
                "text": text,
                "model_id": "eleven_turbo_v2_5",
                "voice_settings": {"stability": 0.6, "similarity_boost": 0.75},
            },
            timeout=90,
        )
        response.raise_for_status()
        destination.write_bytes(response.content)
        print(f"Generated {args.locale}/audio/{destination.name}", flush=True)


if __name__ == "__main__":
    main()
