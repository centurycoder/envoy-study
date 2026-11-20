#!/bin/sh

BASE_DIR=$(CDPATH= cd -P "$(dirname "$0")" && pwd) || exit 1

usage() {
    cat <<EOF
Usage: $BASE_DIR/setup.sh {start|stop|status} [all|http|grpc|unhealthy]
       $BASE_DIR/setup.sh {-h|--help}

The selector defaults to all. All actions run HTTP, then gRPC, then unhealthy;
all are attempted even if an earlier child fails, and the first child failure
is returned.

Examples:
  "$BASE_DIR/setup.sh" start http
  "$BASE_DIR/setup.sh" start grpc
  "$BASE_DIR/setup.sh" start unhealthy
  "$BASE_DIR/setup.sh" start all
  "$BASE_DIR/setup.sh" status
  "$BASE_DIR/setup.sh" stop all

Individual service commands (usable from any working directory):
  "$BASE_DIR/http/setup.sh" {start|stop|status}
  "$BASE_DIR/grpc/setup.sh" {start|stop|status}
  "$BASE_DIR/unhealthy/setup.sh" {start|stop|status}

Services and runtime files:
  HTTP: service-1 on port 8081; service-2 on port 8082.
  gRPC: 192.168.138.129:50051 by default.
  Unhealthy: envoy-study-unhealthy on port 8083.
  HTTP logs/PIDs: $BASE_DIR/http/.state/
  gRPC logs/PIDs: $BASE_DIR/grpc/.state/
  Unhealthy logs/PIDs: $BASE_DIR/unhealthy/.state/

Environment overrides:
  BIND    Shared override; HTTP and unhealthy default to 0.0.0.0,
          gRPC to 192.168.138.129.
  PYTHON  HTTP and unhealthy interpreter, default python3.
  PORT    gRPC port, default 50051.
  gRPC always uses $BASE_DIR/grpc/.venv/bin/python.

Unhealthy service checks (lab use only; intentionally slow/unhealthy):
  curl -i http://127.0.0.1:8083/health
    Expected: immediate HTTP 503; do not use curl --fail for this check.
  curl -i http://127.0.0.1:8083/slow
    Expected: HTTP 200 after approximately 3 seconds.
  Warning: lab-only service; do not expose it on untrusted networks.

Prepare the gRPC environment (not performed automatically):
  python3 -m venv "$BASE_DIR/grpc/.venv"
  "$BASE_DIR/grpc/.venv/bin/python" -m pip install -r "$BASE_DIR/grpc/requirements.txt"

Regenerate gRPC Python modules from the project directory:
  cd "$BASE_DIR"
  grpc/.venv/bin/python -m grpc_tools.protoc -I grpc --python_out=grpc --grpc_python_out=grpc grpc/info.proto

Query gRPC using the moved proto import path:
  grpcurl -plaintext -import-path "$BASE_DIR/grpc" -proto info.proto -d '{}' 192.168.138.129:50051 envoystudy.v1.InfoService/GetInfo
EOF
}

usage_error() {
    printf '%s\n' "Error: $1" >&2
    usage >&2
    exit 2
}

if [ "$#" -eq 1 ]; then
    case "$1" in
        -h|--help) usage; exit 0 ;;
    esac
fi

case "$#" in
    1|2) ;;
    *) usage_error 'Expected an action and an optional service selector.' ;;
esac

action=$1
selector=${2-all}

case "$action" in
    start|stop|status) ;;
    *) usage_error "Unknown action: $action" ;;
esac

case "$selector" in
    all|http|grpc|unhealthy) ;;
    *) usage_error "Unknown service selector: $selector" ;;
esac

case "$selector" in
    http|grpc|unhealthy) exec "$BASE_DIR/$selector/setup.sh" "$action" ;;
esac

http_status=0
"$BASE_DIR/http/setup.sh" "$action" || http_status=$?
grpc_status=0
"$BASE_DIR/grpc/setup.sh" "$action" || grpc_status=$?
unhealthy_status=0
"$BASE_DIR/unhealthy/setup.sh" "$action" || unhealthy_status=$?

[ "$http_status" -eq 0 ] || exit "$http_status"
[ "$grpc_status" -eq 0 ] || exit "$grpc_status"
exit "$unhealthy_status"
