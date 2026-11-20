#!/bin/sh
set -eu

BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STATE_DIR="$BASE_DIR/.state"
PYTHON=${PYTHON:-python3}
BIND=${BIND:-0.0.0.0}

usage() {
    echo "Usage: $0 {start|stop|status}" >&2
    exit 2
}

help() {
    cat <<EOF
Usage: $0 {start|stop|status}
       $0 {-h|--help}

Run this script directly from any working directory, for example:
  /home/nmei/envoy-study/http/setup.sh start
  /home/nmei/envoy-study/http/setup.sh status
  /home/nmei/envoy-study/http/setup.sh stop

Requires Python 3 (standard library only; no package installation needed).
Starts service-1 on port 8081 and service-2 on port 8082, both version 1.0.0.

Environment:
  BIND    Listen address (default: 0.0.0.0).
  PYTHON  Python executable (default: python3).

Logs and PID files are stored in $BASE_DIR/.state/.
EOF
}

pid_file() {
    printf '%s/%s.pid\n' "$STATE_DIR" "$1"
}

is_service_running() {
    name=$1
    file=$(pid_file "$name")
    [ -r "$file" ] || return 1
    pid=$(cat "$file")
    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac
    kill -0 "$pid" 2>/dev/null || return 1
    args=$(ps -p "$pid" -o args= 2>/dev/null || true)
    case "$args" in
        *"$BASE_DIR/http_service.py"*"--name $name "*) return 0 ;;
        *) return 1 ;;
    esac
}

start_service() {
    name=$1
    port=$2
    file=$(pid_file "$name")
    log_file="$STATE_DIR/$name.log"

    if is_service_running "$name"; then
        echo "$name already running (pid $(cat "$file"))"
        return 0
    fi

    rm -f "$file"
    nohup "$PYTHON" "$BASE_DIR/http_service.py" \
        --name "$name" --version 1.0.0 --bind "$BIND" --port "$port" \
        >>"$log_file" 2>&1 </dev/null &
    pid=$!
    printf '%s\n' "$pid" > "$file"
    sleep 1

    if is_service_running "$name"; then
        echo "$name started on $BIND:$port (pid $pid)"
        return 0
    fi

    rm -f "$file"
    echo "Failed to start $name; see $log_file" >&2
    return 1
}

stop_service() {
    name=$1
    file=$(pid_file "$name")

    if ! is_service_running "$name"; then
        rm -f "$file"
        echo "$name is not running"
        return 0
    fi

    pid=$(cat "$file")
    kill -TERM "$pid"
    tries=0
    while is_service_running "$name" && [ "$tries" -lt 5 ]; do
        sleep 1
        tries=$((tries + 1))
    done
    if is_service_running "$name"; then
        kill -KILL "$pid"
    fi
    rm -f "$file"
    echo "$name stopped"
}

status_service() {
    name=$1
    file=$(pid_file "$name")
    if is_service_running "$name"; then
        echo "$name running (pid $(cat "$file"))"
    else
        echo "$name stopped"
    fi
}

[ "$#" -eq 1 ] || usage
case "$1" in
    -h|--help)
        help
        ;;
    start)
        mkdir -p "$STATE_DIR"
        start_service service-1 8081 || exit 1
        if ! start_service service-2 8082; then
            stop_service service-1
            exit 1
        fi
        ;;
    stop)
        stop_service service-1
        stop_service service-2
        ;;
    status)
        status_service service-1
        status_service service-2
        ;;
    *)
        usage
        ;;
esac
