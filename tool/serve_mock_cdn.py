"""Serves mock_cdn/ like Tolgee Content Delivery, with CORS so Flutter Web works.

Usage: python3 -I tool/serve_mock_cdn.py [port]   (default 8787)
Edit a file in mock_cdn/ and tap "Fetch from CDN" (or background/resume the app).
"""
import functools
import http.server
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "mock_cdn"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


handler = functools.partial(Handler, directory=str(ROOT))
print(f"Mock Tolgee CDN on http://localhost:{PORT} serving {ROOT}")
http.server.ThreadingHTTPServer(("0.0.0.0", PORT), handler).serve_forever()
