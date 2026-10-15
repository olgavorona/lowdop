#!/usr/bin/env python3
"""Generate one shared ElevenLabs answer narration track for every app story."""

from __future__ import annotations

import json
import os
from pathlib import Path

import requests


ROOT = Path(__file__).resolve().parents[1]
LABYRINTHS = ROOT / "LowDopamineLabyrinth" / "LowDopamineLabyrinth" / "Resources" / "Labyrinths"
AUDIO = LABYRINTHS / "audio"
MANIFEST = LABYRINTHS / "manifest.json"


def generate(api_url: str, headers: dict[str, str], text: str, destination: Path) -> None:
    if destination.exists():
        print(f"Skipping {destination.name} (already exists)", flush=True)
        return

    response = requests.post(
        api_url,
        headers=headers,
        json={
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": {"stability": 0.6, "similarity_boost": 0.75},
        },
        timeout=60,
    )
    response.raise_for_status()
    destination.write_bytes(response.content)
    print(f"Generated {destination.name}", flush=True)


def main() -> None:
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        raise SystemExit("ELEVENLABS_API_KEY is not set")

    # Charlotte: the warm female voice used by the existing app narration.
    voice_id = os.environ.get("ELEVENLABS_VOICE_ID", "XB0fDUnXU5powFXDhCwa")
    api_url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    headers = {
        "xi-api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    }
    AUDIO.mkdir(parents=True, exist_ok=True)

    manifest = json.loads(MANIFEST.read_text())
    entries_by_story: dict[int, list[dict]] = {}
    for entry in manifest["labyrinths"]:
        story = entry.get("story")
        if story is not None:
            entries_by_story.setdefault(story, []).append(entry)

    for story in sorted(entries_by_story):
        entries = entries_by_story[story]
        preferred = next((item for item in entries if item["difficulty"] == "easy"), entries[0])
        labyrinth = json.loads((LABYRINTHS / f"{preferred['id']}.json").read_text())
        answer = labyrinth.get("fun_fact", "").strip()
        if not answer:
            print(f"Skipping story {story}: no answer text", flush=True)
            continue
        generate(
            api_url,
            headers,
            answer,
            AUDIO / f"denny_{story:03d}_answer.mp3",
        )


if __name__ == "__main__":
    main()
