#!/usr/bin/env python3
"""Deliberately slow and unhealthy HTTP JSON service for lab use only."""

import argparse
import json
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class ServiceHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        if self.path == "/slow":
            time.sleep(3)
            code = 200
            status = "slow"
        elif self.path in ("/", "/health"):
            code = 503
            status = "unhealthy"
        else:
            code = 404
            status = "not_found"

        payload = {
            "service": self.server.service_name,
            "version": self.server.service_version,
            "hostname": socket.gethostname(),
            "status": status,
        }
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    parser = argparse.ArgumentParser(
        description="Lab-only service: /slow waits 3 seconds; / and /health return 503."
    )
    parser.add_argument("--name", required=True, help="Service name returned in JSON")
    parser.add_argument("--version", required=True, help="Service version returned in JSON")
    parser.add_argument("--bind", default="0.0.0.0", help="Address to listen on")
    parser.add_argument("--port", type=int, required=True, help="TCP port to listen on")
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.bind, args.port), ServiceHandler)
    server.service_name = args.name
    server.service_version = args.version
    print(f"Serving {args.name} {args.version} on {args.bind}:{args.port}", flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
