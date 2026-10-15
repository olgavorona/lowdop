#!/usr/bin/env python3
"""Serve generated localized narration files to the iOS Simulator app."""

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse
import json


ROOT = Path(__file__).resolve().parents[1] / "content-generator" / "localized-audio"
HOST = "127.0.0.1"
PORT = 8765
SUPPORTED_LANGUAGES = {"de", "es"}


class AudioHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        route = unquote(urlparse(self.path).path).strip("/").split("/")
        if len(route) == 2 and route[0] in SUPPORTED_LANGUAGES and route[1] == "manifest.json":
            audio_dir = ROOT / route[0] / "audio"
            files = sorted(path.name for path in audio_dir.glob("*.mp3") if path.is_file())
            body = json.dumps(files).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if len(route) == 3 and route[0] in SUPPORTED_LANGUAGES and route[1] == "audio":
            filename = route[2]
            if filename.endswith(".mp3") and Path(filename).name == filename:
                audio_file = ROOT / route[0] / "audio" / filename
                if audio_file.is_file():
                    self.path = f"/{route[0]}/audio/{filename}"
                    return super().do_GET()

        self.send_error(404, "Audio resource not found")

    def translate_path(self, path):
        parts = [part for part in unquote(urlparse(path).path).split("/") if part]
        if len(parts) == 3 and parts[0] in SUPPORTED_LANGUAGES and parts[1] == "audio":
            return str(ROOT / parts[0] / "audio" / Path(parts[2]).name)
        return str(ROOT / "__not_found__")


if __name__ == "__main__":
    if not ROOT.is_dir():
        raise SystemExit(f"Localized audio directory not found: {ROOT}")
    server = ThreadingHTTPServer((HOST, PORT), AudioHandler)
    print(f"Serving localized audio from {ROOT} at http://{HOST}:{PORT}")
    print("Stop with Ctrl+C.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Stopping local audio mock server.")
        server.server_close()
