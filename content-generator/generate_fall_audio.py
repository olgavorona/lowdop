#!/usr/bin/env python3
"""Generate shared ElevenLabs narration for the six Fall app stories."""

from __future__ import annotations

import json
import os
from pathlib import Path

import requests


ROOT = Path(__file__).resolve().parents[1]
LABYRINTHS = ROOT / "LowDopamineLabyrinth" / "LowDopamineLabyrinth" / "Resources" / "Labyrinths"
AUDIO = LABYRINTHS / "audio"
STORIES = range(61, 67)


def generate(
    api_url: str,
    headers: dict[str, str],
    text: str,
    destination: Path,
    overwrite: bool = False,
) -> None:
    if destination.exists() and not overwrite:
        print(f"Skipping {destination.name} (already exists)")
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
    print(f"Generated {destination.name}")


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
    selected_story = os.environ.get("FALL_AUDIO_STORY")
    selected_track = os.environ.get("FALL_AUDIO_TRACK")
    overwrite = os.environ.get("FALL_AUDIO_OVERWRITE") == "1"

    for story in STORIES:
        if selected_story and story != int(selected_story):
            continue
        labyrinth = json.loads((LABYRINTHS / f"denny_{story:03d}_easy.json").read_text())
        tracks = {
            "instruction": labyrinth["tts_instruction"],
            "completion": f"{labyrinth['completion_message']} {labyrinth['educational_question']}",
            "answer": labyrinth["fun_fact"],
        }
        for track, text in tracks.items():
            if selected_track and track != selected_track:
                continue
            generate(
                api_url,
                headers,
                text,
                AUDIO / f"denny_{story:03d}_{track}.mp3",
                overwrite=overwrite,
            )


if __name__ == "__main__":
    main()
