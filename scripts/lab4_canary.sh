#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export PATH="$HOME/.local/bin:$PATH"

NAMESPACE="chatbot-canary"
ROLLOUT="chatbot"
HOST="canary.127.0.0.1.nip.io"
URL="http://127.0.0.1:8085"
PF_PID_FILE="/tmp/opencode/ingress-port-forward.pid"
LOAD_PID_FILE="/tmp/opencode/canary-load.pid"
LOAD_FILE="/tmp/opencode/canary-load.json"

log() { echo "[canary] $*"; }

start_port_forward() {
    mkdir -p /tmp/opencode
    if [ -f "$PF_PID_FILE" ] && kill -0 "$(cat "$PF_PID_FILE")" 2>/dev/null; then
        return 0
    fi

    log "Starting an ingress port-forward on 8085..."
    kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8085:80 \
        >/tmp/opencode/ingress-port-forward.log 2>&1 &
    echo $! > "$PF_PID_FILE"

    for _ in $(seq 1 20); do
        code=$(curl -s -o /dev/null -w '%{http_code}' -H "Host: $HOST" "$URL/health" || true)
        if [ -n "$code" ] && [ "$code" != "000" ]; then
            return 0
        fi
        sleep 1
    done
    echo "Ingress port-forward did not become reachable." >&2
    return 1
}

stop_port_forward() {
    if [ -f "$PF_PID_FILE" ]; then
        kill "$(cat "$PF_PID_FILE")" 2>/dev/null || true
        rm -f "$PF_PID_FILE"
    fi
}

sample() {
    local count="${1:-100}"
    start_port_forward
    python3 scripts/lab4_traffic.py sample \
        --url "$URL/health" \
        --host "$HOST" \
        --count "$count" \
        --interval 0.05 \
        --output /tmp/opencode/canary-sample.json
}

load_start() {
    local duration="${1:-900}"
    start_port_forward
    if [ -f "$LOAD_PID_FILE" ] && kill -0 "$(cat "$LOAD_PID_FILE")" 2>/dev/null; then
        log "Load generator is already running."
        return 0
    fi
    log "Generating traffic through the ingress for ${duration}s..."
    nohup python3 scripts/lab4_traffic.py probe \
        --url "$URL/health" \
        --host "$HOST" \
        --duration "$duration" \
        --interval 0.1 \
        --output "$LOAD_FILE" >/dev/null 2>&1 &
    echo $! > "$LOAD_PID_FILE"
}

load_stop() {
    if [ -f "$LOAD_PID_FILE" ]; then
        kill -INT "$(cat "$LOAD_PID_FILE")" 2>/dev/null || true
        rm -f "$LOAD_PID_FILE"
        sleep 2
    fi
    if [ -f "$LOAD_FILE" ]; then
        log "Cumulative traffic distribution:"
        cat "$LOAD_FILE"
    fi
}

status() {
    kubectl argo rollouts get rollout "$ROLLOUT" -n "$NAMESPACE"
}

case "${1:-status}" in
    status)
        status
        ;;
    sample)
        sample "${2:-100}"
        ;;
    load-start)
        load_start "${2:-900}"
        ;;
    load-stop)
        load_stop
        ;;
    promote)
        kubectl argo rollouts promote "$ROLLOUT" -n "$NAMESPACE"
        ;;
    abort)
        log "Aborting the canary; traffic returns to the stable version."
        kubectl argo rollouts abort "$ROLLOUT" -n "$NAMESPACE"
        ;;
    retry)
        kubectl argo rollouts retry rollout "$ROLLOUT" -n "$NAMESPACE"
        ;;
    undo)
        kubectl argo rollouts undo "$ROLLOUT" -n "$NAMESPACE"
        ;;
    watch)
        kubectl argo rollouts get rollout "$ROLLOUT" -n "$NAMESPACE" --watch
        ;;
    steps)
        kubectl get rollout "$ROLLOUT" -n "$NAMESPACE" -o jsonpath='{.spec.strategy.canary.steps}' | python3 -m json.tool
        ;;
    port-forward-stop)
        stop_port_forward
        ;;
    *)
        echo "Usage: $0 {status|sample [n]|load-start [seconds]|load-stop|promote|abort|retry|undo|watch|steps|port-forward-stop}" >&2
        exit 1
        ;;
esac
