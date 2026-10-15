#!/usr/bin/env python3
"""Serve the local image-maze annotation editor."""

from __future__ import annotations

import argparse
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


HTML_PATH = Path(__file__).resolve().with_name("image_maze_editor.html")


class ImageMazeEditorHandler(BaseHTTPRequestHandler):
    server_version = "ImageMazeEditor/1.0"

    def do_GET(self) -> None:
        if self.path not in {"/", "/index.html"}:
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        body = HTML_PATH.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args) -> None:  # noqa: A003
        return


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the image-maze annotation editor.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8125)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), ImageMazeEditorHandler)
    print(f"Image maze editor running at http://{args.host}:{args.port}")
    print("Import an image, place markers and collectibles, then export PNG + JSON.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
