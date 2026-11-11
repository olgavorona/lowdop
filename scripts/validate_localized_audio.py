#!/usr/bin/env python3
"""Check localized track coverage, metadata, and complete MP3 decoding."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "content-generator/localized-audio"
ENGLISH = ROOT / "LowDopamineLabyrinth/LowDopamineLabyrinth/Resources/Labyrinths/audio"


def inspect(path: Path) -> dict:
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)],
        capture_output=True, text=True, check=True,
    )
    metadata = json.loads(probe.stdout)
    streams = metadata["streams"]
    if len(streams) != 1 or streams[0].get("codec_name") != "mp3":
        raise ValueError(f"{path}: expected one MP3 stream")
    stream = streams[0]
    duration = float(metadata["format"]["duration"])
    if stream.get("sample_rate") != "44100" or stream.get("channels") != 1 or duration <= 0.2:
        raise ValueError(f"{path}: unexpected audio format or empty recording")
    subprocess.run(
        ["ffmpeg", "-v", "error", "-xerror", "-i", str(path), "-f", "null", "-"],
        capture_output=True, check=True,
    )
    return {"filename": path.name, "bytes": path.stat().st_size, "seconds": duration,
            "sample_rate": 44100, "channels": 1}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("locales", nargs="+")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    expected = {p.name for p in ENGLISH.glob("*.mp3")}
    if not expected:
        raise ValueError("English track inventory is empty")
    report = {}
    for locale in args.locales:
        if locale not in {"de", "es", "ja", "zh-Hans", "ko", "ar", "sv", "fi", "nl"}:
            raise ValueError(f"Unsupported locale: {locale}")
        paths = sorted((AUDIO / locale / "audio").glob("*.mp3"))
        actual = {p.name for p in paths}
        scripts = json.loads((AUDIO / f"narration-{locale}.json").read_text())
        if actual != expected or {f"{key}.mp3" for key in scripts} != expected:
            raise ValueError(f"{locale}: track coverage mismatch; missing={sorted(expected-actual)}, extra={sorted(actual-expected)}")
        with ThreadPoolExecutor(max_workers=4) as executor:
            tracks = list(executor.map(inspect, paths))
        report[locale] = {"tracks": tracks, "count": len(tracks),
                          "total_seconds": sum(t["seconds"] for t in tracks),
                          "total_bytes": sum(t["bytes"] for t in tracks)}
        print(f"{locale}: all {len(tracks)} tracks decoded; 44.1 kHz mono MP3; {report[locale]['total_seconds']/60:.1f} minutes", flush=True)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
