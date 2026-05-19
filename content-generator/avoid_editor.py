#!/usr/bin/env python3
"""Local browser editor for avoid-item placement."""

from __future__ import annotations

import argparse
import json
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


ROOT_DIR = Path(__file__).resolve().parent.parent
LAB_DIR = ROOT_DIR / "LowDopamineLabyrinth" / "LowDopamineLabyrinth" / "Resources" / "Labyrinths"
HTML_PATH = Path(__file__).resolve().with_name("avoid_editor.html")
AVOID_TARGETS = {"easy": 1, "medium": 3, "hard": 4}


def load_labyrinth(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def avoid_paths() -> list[Path]:
    paths = []
    for path in sorted(LAB_DIR.glob("denny_*.json")):
        data = load_labyrinth(path)
        if data.get("item_rule") == "avoid":
            paths.append(path)
    return paths


def level_metadata(path: Path) -> dict:
    lab = load_labyrinth(path)
    story_number = int(lab["id"].split("_")[1])
    return {
        "id": lab["id"],
        "title": lab["title"],
        "theme": lab["theme"],
        "difficulty": lab["difficulty"],
        "story_number": story_number,
        "required_count": AVOID_TARGETS.get(lab["difficulty"], len(lab["path_data"].get("avoid_items", []))),
        "file": str(path.relative_to(ROOT_DIR)),
    }


class AvoidEditorHandler(BaseHTTPRequestHandler):
    server_version = "AvoidEditor/1.0"

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self._send_html()
            return
        if parsed.path == "/api/levels":
            levels = [level_metadata(path) for path in avoid_paths()]
            self._send_json({"levels": levels})
            return
        if parsed.path == "/api/level":
            level_id = parse_qs(parsed.query).get("id", [None])[0]
            if not level_id:
                self._send_error_json(HTTPStatus.BAD_REQUEST, "Missing level id")
                return
            path = LAB_DIR / f"{level_id}.json"
            if not path.exists():
                self._send_error_json(HTTPStatus.NOT_FOUND, f"Unknown level: {level_id}")
                return
            lab = load_labyrinth(path)
            lab["_editor"] = {
                "required_count": AVOID_TARGETS.get(lab["difficulty"], len(lab["path_data"].get("avoid_items", []))),
                "file": str(path.relative_to(ROOT_DIR)),
            }
            self._send_json(lab)
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
        except json.JSONDecodeError:
            self._send_error_json(HTTPStatus.BAD_REQUEST, "Invalid JSON")
            return

        level_id = data.get("id")
        avoid_items = data.get("avoid_items")
        if not level_id or not isinstance(avoid_items, list):
            self._send_error_json(HTTPStatus.BAD_REQUEST, "Expected id and avoid_items")
            return

        path = LAB_DIR / f"{level_id}.json"
        if not path.exists():
            self._send_error_json(HTTPStatus.NOT_FOUND, f"Unknown level: {level_id}")
            return

        lab = load_labyrinth(path)
        expected = AVOID_TARGETS.get(lab["difficulty"], len(avoid_items))
        if len(avoid_items) != expected:
            self._send_error_json(
                HTTPStatus.BAD_REQUEST,
                f"{level_id} expects {expected} avoid items, got {len(avoid_items)}",
            )
            return

        emoji = lab.get("item_emoji", "")
        normalized = []
        for item in avoid_items:
            try:
                x = round(float(item["x"]), 1)
                y = round(float(item["y"]), 1)
            except (KeyError, TypeError, ValueError):
                self._send_error_json(HTTPStatus.BAD_REQUEST, "Every item needs numeric x and y")
                return
            normalized.append({
                "x": x,
                "y": y,
                "emoji": emoji,
                "on_solution": False,
            })

        lab["path_data"]["avoid_items"] = normalized
        path.write_text(json.dumps(lab, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        self._send_json({"ok": True, "saved": level_id, "path": str(path.relative_to(ROOT_DIR))})

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
    parser = argparse.ArgumentParser(description="Run the avoid-level placement editor.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8123)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), AvoidEditorHandler)
    print(f"Avoid editor running at http://{args.host}:{args.port}")
    print("Open that URL in your browser. Changes save directly into the app JSON files.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
