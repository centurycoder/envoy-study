#!/usr/bin/env python3
"""gRPC info service for the envoy-study lab."""

import argparse
import base64
import socket
from concurrent import futures

import grpc

import info_pb2
import info_pb2_grpc


REDACTED_METADATA = {
    "authorization",
    "proxy-authorization",
    "cookie",
    "x-api-key",
}


class InfoService(info_pb2_grpc.InfoServiceServicer):
    def __init__(self, service_name, version):
        self.service_name = service_name
        self.version = version

    def GetInfo(self, request, context):
        metadata = []
        for entry in context.invocation_metadata():
            key = entry.key
            if key.lower() in REDACTED_METADATA:
                value = "[REDACTED]"
            elif isinstance(entry.value, bytes):
                value = base64.b64encode(entry.value).decode("ascii")
            else:
                value = entry.value
            metadata.append(info_pb2.MetadataEntry(key=key, value=value))

        return info_pb2.InfoResponse(
            service_name=self.service_name,
            version=self.version,
            hostname=socket.gethostname(),
            metadata=metadata,
        )


def main():
    parser = argparse.ArgumentParser(description="Return service metadata and incoming gRPC metadata.")
    parser.add_argument("--name", required=True, help="Service name returned by GetInfo")
    parser.add_argument("--version", required=True, help="Service version returned by GetInfo")
    parser.add_argument("--bind", default="127.0.0.1", help="Address to listen on")
    parser.add_argument("--port", type=int, required=True, help="TCP port to listen on")
    args = parser.parse_args()

    server = grpc.server(futures.ThreadPoolExecutor(max_workers=8))
    info_pb2_grpc.add_InfoServiceServicer_to_server(
        InfoService(args.name, args.version), server
    )
    address = f"{args.bind}:{args.port}"
    if server.add_insecure_port(address) == 0:
        raise RuntimeError(f"Could not bind gRPC server to {address}")

    server.start()
    print(f"Serving {args.name} {args.version} on {address}", flush=True)
    server.wait_for_termination()


if __name__ == "__main__":
    main()
