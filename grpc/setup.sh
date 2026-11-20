#!/bin/sh
set -eu

BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STATE_DIR="$BASE_DIR/.state"
PYTHON="$BASE_DIR/.venv/bin/python"
BIND=${BIND:-192.168.138.129}
PORT=${PORT:-50051}
SERVICE_NAME=envoy-study-grpc
VERSION=1.0.0
PID_FILE="$STATE_DIR/grpc_service.pid"
LOG_FILE="$STATE_DIR/grpc_service.log"

usage() {
    cat <<EOF
Usage: $0 {start|stop|status}
       $0 {-h|--help}

Manage envoy-study-grpc 1.0.0 from any working directory.
BIND defaults to 192.168.138.129; PORT defaults to 50051.
Logs and PID files are stored in "$STATE_DIR".

Set up the gRPC Python environment before starting:
  python3 -m venv "$BASE_DIR/.venv"
  "$PYTHON" -m pip install -r "$BASE_DIR/requirements.txt"

The Python used for setup must provide venv and pip support.
EOF
}

is_service_running() {
    [ -r "$PID_FILE" ] || return 1
    pid=$(cat "$PID_FILE")
    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac
    kill -0 "$pid" 2>/dev/null || return 1
    args=$(ps -p "$pid" -o args= 2>/dev/null || true)
    case "$args" in
        *"$BASE_DIR/grpc_server.py"*"--name $SERVICE_NAME "*) return 0 ;;
        *) return 1 ;;
    esac
}

start_service() {
    if is_service_running; then
        echo "$SERVICE_NAME already running (pid $(cat "$PID_FILE"))"
        return 0
    fi
    if [ ! -x "$PYTHON" ]; then
        echo "Missing gRPC virtualenv: $PYTHON" >&2
        echo "Run '$0 --help' for setup commands using $BASE_DIR/requirements.txt" >&2
        return 1
    fi

    rm -f "$PID_FILE"
    nohup "$PYTHON" "$BASE_DIR/grpc_server.py" \
        --name "$SERVICE_NAME" --version "$VERSION" --bind "$BIND" --port "$PORT" \
        >>"$LOG_FILE" 2>&1 </dev/null &
    pid=$!
    printf '%s\n' "$pid" > "$PID_FILE"
    sleep 1

    if is_service_running; then
        echo "$SERVICE_NAME started on $BIND:$PORT (pid $pid)"
        return 0
    fi

    rm -f "$PID_FILE"
    echo "Failed to start $SERVICE_NAME; see $LOG_FILE" >&2
    return 1
}

stop_service() {
    if ! is_service_running; then
        rm -f "$PID_FILE"
        echo "$SERVICE_NAME is not running"
        return 0
    fi

    pid=$(cat "$PID_FILE")
    kill -TERM "$pid"
    tries=0
    while is_service_running && [ "$tries" -lt 5 ]; do
        sleep 1
        tries=$((tries + 1))
    done
    if is_service_running; then
        kill -KILL "$pid"
    fi
    rm -f "$PID_FILE"
    echo "$SERVICE_NAME stopped"
}

[ "$#" -eq 1 ] || { usage >&2; exit 2; }
case "$1" in
    start)
        mkdir -p "$STATE_DIR"
        start_service
        ;;
    stop)
        stop_service
        ;;
    status)
        if is_service_running; then
            echo "$SERVICE_NAME running (pid $(cat "$PID_FILE"))"
        else
            echo "$SERVICE_NAME stopped"
        fi
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
