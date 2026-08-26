#!/usr/bin/env python3
"""Local browser editor for letter stroke cue placement."""

from __future__ import annotations

import argparse
import json
import re
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


ROOT_DIR = Path(__file__).resolve().parent.parent
HTML_PATH = Path(__file__).resolve().with_name("stroke_editor.html")
DATA_PATH = Path(__file__).resolve().with_name("letter_stroke_cues.json")
SWIFT_PATH = ROOT_DIR / "LowDopScribble" / "LowDopScribble" / "Views" / "LetterTracingView.swift"
LETTERS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
BEGIN_MARKER = "    // BEGIN GENERATED LETTER STROKE CUES"
END_MARKER = "    // END GENERATED LETTER STROKE CUES"


def clamp_unit(value: object) -> float:
    numeric = float(value)
    return round(max(0.0, min(1.0, numeric)), 3)


def stroke_from_match(match: re.Match[str]) -> dict:
    values = [clamp_unit(value) for value in match.groups()[1:] if value is not None]
    if len(values) == 6:
        return cubic_from_quadratic(
            int(match.group(1)),
            {"x": values[0], "y": values[1]},
            {"x": values[2], "y": values[3]},
            {"x": values[4], "y": values[5]},
        )

    return {
        "order": int(match.group(1)),
        "start": {"x": values[0], "y": values[1]},
        "control1": {"x": values[2], "y": values[3]},
        "control2": {"x": values[4], "y": values[5]},
        "end": {"x": values[6], "y": values[7]},
    }


def default_cues() -> dict[str, list[dict]]:
    return {
        letter: [{
            "order": 1,
            "start": {"x": 0.3, "y": 0.18},
            "control1": {"x": 0.3, "y": 0.36},
            "control2": {"x": 0.3, "y": 0.58},
            "end": {"x": 0.3, "y": 0.76},
        }]
        for letter in LETTERS
    }


def cubic_from_quadratic(order: int, start: dict, control: dict, end: dict) -> dict:
    return {
        "order": order,
        "start": {"x": clamp_unit(start["x"]), "y": clamp_unit(start["y"])},
        "control1": {
            "x": clamp_unit(float(start["x"]) + (2.0 / 3.0) * (float(control["x"]) - float(start["x"]))),
            "y": clamp_unit(float(start["y"]) + (2.0 / 3.0) * (float(control["y"]) - float(start["y"]))),
        },
        "control2": {
            "x": clamp_unit(float(end["x"]) + (2.0 / 3.0) * (float(control["x"]) - float(end["x"]))),
            "y": clamp_unit(float(end["y"]) + (2.0 / 3.0) * (float(control["y"]) - float(end["y"]))),
        },
        "end": {"x": clamp_unit(end["x"]), "y": clamp_unit(end["y"])},
    }


def parse_cues_from_swift() -> dict[str, list[dict]]:
    source = SWIFT_PATH.read_text(encoding="utf-8")
    cues = default_cues()
    letter_pattern = re.compile(r'"([A-Z])": \[(.*?)\]\s*(?:,|\n\s*\])', re.DOTALL)
    stroke_pattern = re.compile(
        r"stroke\((\d+),\s*"
        r"([0-9.]+),\s*([0-9.]+),\s*"
        r"([0-9.]+),\s*([0-9.]+),\s*"
        r"([0-9.]+),\s*([0-9.]+)"
        r"(?:,\s*([0-9.]+),\s*([0-9.]+))?\)"
    )

    for letter_match in letter_pattern.finditer(source):
        letter = letter_match.group(1)
        strokes = [stroke_from_match(match) for match in stroke_pattern.finditer(letter_match.group(2))]
        if strokes:
            cues[letter] = sorted(strokes, key=lambda stroke: stroke["order"])
    return cues


def normalize_strokes(strokes: object) -> list[dict]:
    if not isinstance(strokes, list) or not strokes:
        raise ValueError("Expected at least one stroke")

    normalized = []
    for index, stroke in enumerate(strokes, start=1):
        if not isinstance(stroke, dict):
            raise ValueError("Every stroke must be an object")
        try:
            if "control1" not in stroke or "control2" not in stroke:
                migrated = cubic_from_quadratic(index, stroke["start"], stroke["control"], stroke["end"])
                stroke = migrated
            normalized.append({
                "order": index,
                "start": {
                    "x": clamp_unit(stroke["start"]["x"]),
                    "y": clamp_unit(stroke["start"]["y"]),
                },
                "control1": {
                    "x": clamp_unit(stroke["control1"]["x"]),
                    "y": clamp_unit(stroke["control1"]["y"]),
                },
                "control2": {
                    "x": clamp_unit(stroke["control2"]["x"]),
                    "y": clamp_unit(stroke["control2"]["y"]),
                },
                "end": {
                    "x": clamp_unit(stroke["end"]["x"]),
                    "y": clamp_unit(stroke["end"]["y"]),
                },
            })
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError("Every stroke needs numeric start, control, and end points") from exc
    return normalized


def load_cues() -> dict[str, list[dict]]:
    if DATA_PATH.exists():
        data = json.loads(DATA_PATH.read_text(encoding="utf-8"))
        cues = default_cues()
        for letter in LETTERS:
            if letter in data:
                cues[letter] = normalize_strokes(data[letter])
        return cues

    cues = parse_cues_from_swift()
    save_json(cues)
    return cues


def save_json(cues: dict[str, list[dict]]) -> None:
    ordered = {letter: cues.get(letter, default_cues()[letter]) for letter in LETTERS}
    DATA_PATH.write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def fmt(value: float) -> str:
    return f"{value:.3f}".rstrip("0").rstrip(".")


def swift_dictionary(cues: dict[str, list[dict]]) -> str:
    lines = [
        BEGIN_MARKER,
        "    private static let cues: [String: [LetterStrokeCue]] = [",
    ]
    for letter_index, letter in enumerate(LETTERS):
        strokes = cues.get(letter, default_cues()[letter])
        lines.append(f'        "{letter}": [')
        for stroke_index, stroke in enumerate(strokes):
            comma = "," if stroke_index < len(strokes) - 1 else ""
            lines.append(
                "            "
                f"stroke({stroke['order']}, "
                f"{fmt(stroke['start']['x'])}, {fmt(stroke['start']['y'])}, "
                f"{fmt(stroke['control1']['x'])}, {fmt(stroke['control1']['y'])}, "
                f"{fmt(stroke['control2']['x'])}, {fmt(stroke['control2']['y'])}, "
                f"{fmt(stroke['end']['x'])}, {fmt(stroke['end']['y'])}){comma}"
            )
        closing = "        ]," if letter_index < len(LETTERS) - 1 else "        ]"
        lines.append(closing)
    lines.extend([
        "    ]",
        END_MARKER,
    ])
    return "\n".join(lines)


def save_swift(cues: dict[str, list[dict]]) -> None:
    source = SWIFT_PATH.read_text(encoding="utf-8")
    start = source.find(BEGIN_MARKER)
    end = source.find(END_MARKER)
    if start == -1 or end == -1 or end <= start:
        raise RuntimeError("Could not find generated cue markers in LetterTracingView.swift")
    end += len(END_MARKER)
    updated = source[:start] + swift_dictionary(cues) + source[end:]
    SWIFT_PATH.write_text(updated, encoding="utf-8")


def metadata(cues: dict[str, list[dict]]) -> list[dict]:
    return [{"letter": letter, "stroke_count": len(cues.get(letter, []))} for letter in LETTERS]


class StrokeEditorHandler(BaseHTTPRequestHandler):
    server_version = "StrokeEditor/1.0"

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self._send_html()
            return

        if parsed.path == "/api/letters":
            cues = load_cues()
            self._send_json({"letters": metadata(cues)})
            return

        if parsed.path == "/api/cues":
            letter = parse_qs(parsed.query).get("letter", [None])[0]
            if letter not in LETTERS:
                self._send_error_json(HTTPStatus.BAD_REQUEST, "Unknown letter")
                return
            cues = load_cues()
            self._send_json({"letter": letter, "strokes": cues[letter]})
            return

        self._send_error_json(HTTPStatus.NOT_FOUND, "Not found")

    def do_POST(self) -> None:
        if self.path != "/api/save":
            self._send_error_json(HTTPStatus.NOT_FOUND, "Not found")
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        payload = self.rfile.read(content_length)
        try:
            data = json.loads(payload.decode("utf-8"))
            letter = data.get("letter")
            strokes = normalize_strokes(data.get("strokes"))
        except (json.JSONDecodeError, ValueError) as exc:
            self._send_error_json(HTTPStatus.BAD_REQUEST, str(exc))
            return

        if letter not in LETTERS:
            self._send_error_json(HTTPStatus.BAD_REQUEST, "Unknown letter")
            return

        try:
            cues = load_cues()
            cues[letter] = strokes
            save_json(cues)
            save_swift(cues)
        except RuntimeError as exc:
            self._send_error_json(HTTPStatus.INTERNAL_SERVER_ERROR, str(exc))
            return

        self._send_json({
            "ok": True,
            "saved": letter,
            "stroke_count": len(strokes),
            "json_path": str(DATA_PATH.relative_to(ROOT_DIR)),
            "swift_path": str(SWIFT_PATH.relative_to(ROOT_DIR)),
        })

    def log_message(self, fmt: str, *args) -> None:  # noqa: A003
        return

    def _send_html(self) -> None:
        html = HTML_PATH.read_text(encoding="utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(html.encode("utf-8"))))
        self.end_headers()
        self.wfile.write(html.encode("utf-8"))

    def _send_json(self, payload: dict, status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_error_json(self, status: HTTPStatus, message: str) -> None:
        self._send_json({"error": message}, status=status)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the letter stroke cue placement editor.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8124)
    args = parser.parse_args()

    load_cues()
    server = ThreadingHTTPServer((args.host, args.port), StrokeEditorHandler)
    print(f"Stroke editor running at http://{args.host}:{args.port}")
    print("Open that URL in your browser. Save writes cue JSON and updates LetterTracingView.swift.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
