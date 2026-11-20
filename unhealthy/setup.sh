#!/bin/sh
set -eu

BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STATE_DIR="$BASE_DIR/.state"
PYTHON=${PYTHON:-python3}
BIND=${BIND:-0.0.0.0}
SERVICE_NAME=envoy-study-unhealthy
PID_FILE="$STATE_DIR/unhealthy_service.pid"
LOG_FILE="$STATE_DIR/unhealthy_service.log"

usage() {
    echo "Usage: $0 {start|stop|status}" >&2
    exit 2
}

help() {
    cat <<EOF
Usage: $0 {start|stop|status}
       $0 {-h|--help}

LAB ONLY: intentionally slow and unhealthy; do not use in production.
Requires Python 3 (standard library only; no package installation needed).
Starts envoy-study-unhealthy version 1.0.0 on fixed port 8083.

Run from any working directory:
  /home/nmei/envoy-study/unhealthy/setup.sh start
  /home/nmei/envoy-study/unhealthy/setup.sh status
  /home/nmei/envoy-study/unhealthy/setup.sh stop

GET / and /health return HTTP 503 immediately with JSON status unhealthy.
GET /slow waits 3 seconds, then returns HTTP 200 with JSON status slow.
Other GET routes return HTTP 404 with JSON status not_found.
Requests run in separate threads so /slow does not delay health checks.
Responses include service, version, hostname and status; no request headers.

Basic verification after starting:
  curl -i http://192.168.138.129:8083/health
  # Expected: HTTP 503, JSON status unhealthy, no intentional delay.
  curl -sS -w '\nHTTP %{http_code}; total %{time_total}s\n' http://192.168.138.129:8083/slow
  # Expected: HTTP 200, JSON status slow, approximately 3 seconds total.

Environment:
  BIND    Listen address (default: 0.0.0.0).
  PYTHON  Python executable (default: python3).

Server:   $BASE_DIR/unhealthy_service.py
PID file: $PID_FILE
Log file: $LOG_FILE
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
        *"$BASE_DIR/unhealthy_service.py"*"--name $SERVICE_NAME "*) return 0 ;;
        *) return 1 ;;
    esac
}

start_service() {
    if is_service_running; then
        echo "$SERVICE_NAME already running (pid $(cat "$PID_FILE"))"
        return 0
    fi

    rm -f "$PID_FILE"
    nohup "$PYTHON" "$BASE_DIR/unhealthy_service.py" \
        --name "$SERVICE_NAME" --version 1.0.0 --bind "$BIND" --port 8083 \
        >>"$LOG_FILE" 2>&1 </dev/null &
    pid=$!
    printf '%s\n' "$pid" > "$PID_FILE"
    sleep 1

    if is_service_running; then
        echo "$SERVICE_NAME started on $BIND:8083 (pid $pid)"
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

status_service() {
    if is_service_running; then
        echo "$SERVICE_NAME running (pid $(cat "$PID_FILE"))"
    else
        echo "$SERVICE_NAME stopped"
    fi
}

[ "$#" -eq 1 ] || usage
case "$1" in
    -h|--help)
        help
        ;;
    start)
        mkdir -p "$STATE_DIR"
        start_service
        ;;
    stop)
        stop_service
        ;;
    status)
        status_service
        ;;
    *)
        usage
        ;;
esac
