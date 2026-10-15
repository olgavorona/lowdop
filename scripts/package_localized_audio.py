#!/usr/bin/env python3
"""Build the German and Spanish Apple-hosted narration pack archives."""

import subprocess
import json
import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "content-generator" / "localized-audio"
OUTPUT = ROOT / "build" / "appstore"
ENGLISH_AUDIO = ROOT / "LowDopamineLabyrinth" / "LowDopamineLabyrinth" / "Resources" / "Labyrinths" / "audio"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--use-existing",
        action="store_true",
        help="Use already packaged audio-de.aar/audio-es.aar files in build/appstore.",
    )
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for language in ("de", "es"):
        manifest = SOURCE / f"Manifest-{language}.json"
        localized_audio = SOURCE / language / "audio"
        archive = OUTPUT / f"audio-{language}.aar"
        expected = {path.name for path in ENGLISH_AUDIO.glob("*.mp3")}
        actual = {path.name for path in localized_audio.glob("*.mp3")}
        missing, extra = sorted(expected - actual), sorted(actual - expected)
        if missing or extra:
            raise SystemExit(
                f"{language} narration files must match the English track set "
                f"({len(expected)} expected, {len(actual)} found); "
                f"missing={missing[:5]}, extra={extra[:5]}"
            )
        definition = json.loads(manifest.read_text(encoding="utf-8"))
        if definition.get("assetPackID") != f"audio-{language}":
            raise SystemExit(f"Unexpected assetPackID in {manifest}")
        if args.use_existing:
            if not archive.is_file():
                raise SystemExit(f"Prebuilt archive is missing: {archive}")
            print(f"Using existing {archive}")
            continue
        subprocess.run(
            ["xcrun", "ba-package", manifest.name, "--output-path", str(archive)],
            cwd=SOURCE,
            check=True,
        )
        print(f"Created {archive}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
