#!/usr/bin/env python3
"""Small configurable HTTP JSON service for the envoy-study lab."""

import argparse
import json
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


REDACTED_HEADERS = {
    "authorization",
    "proxy-authorization",
    "cookie",
    "x-api-key",
}


class ServiceHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        headers = [
            {
                "name": name,
                "value": "[REDACTED]" if name.lower() in REDACTED_HEADERS else value,
            }
            for name, value in self.headers.items()
        ]
        payload = {
            "service": self.server.service_name,
            "version": self.server.service_version,
            "hostname": socket.gethostname(),
            "headers": headers,
        }
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    parser = argparse.ArgumentParser(description="Return service metadata and request headers as JSON.")
    parser.add_argument("--name", required=True, help="Service name returned in JSON")
    parser.add_argument("--version", required=True, help="Service version returned in JSON")
    parser.add_argument("--bind", default="127.0.0.1", help="Address to listen on")
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
