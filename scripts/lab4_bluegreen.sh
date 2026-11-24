#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export PATH="$HOME/.local/bin:$PATH"

NAMESPACE="chatbot"
ROLLOUT="chatbot"
NODE_PORT="30090"
PROBE_FILE="/tmp/opencode/bluegreen-probe.json"

log() { echo "[bluegreen] $*"; }

app_url() {
    echo "http://$(minikube ip):${NODE_PORT}"
}

status() {
    kubectl argo rollouts get rollout "$ROLLOUT" -n "$NAMESPACE"
}

preview() {
    log "Checking the preview Service (the new version before promotion)..."
    kubectl port-forward svc/chatbot-preview -n "$NAMESPACE" 8001:8000 >/tmp/opencode/preview-port-forward.log 2>&1 &
    local pid=$!
    trap 'kill '"$pid"' 2>/dev/null || true' RETURN
    sleep 2
    curl -s http://127.0.0.1:8001/health | python3 -m json.tool
}

promote() {
    mkdir -p /tmp/opencode
    log "Starting a continuous request probe against $(app_url)..."
    python3 scripts/lab4_traffic.py probe \
        --url "$(app_url)/health" \
        --duration 30 \
        --interval 0.2 \
        --output "$PROBE_FILE" >/dev/null &
    local probe_pid=$!

    sleep 2
    log "Promoting the preview version to active..."
    kubectl argo rollouts promote "$ROLLOUT" -n "$NAMESPACE"

    log "Waiting for the rollout to become healthy..."
    kubectl argo rollouts status "$ROLLOUT" -n "$NAMESPACE" --timeout 5m

    wait "$probe_pid"
    echo
    log "Probe result (compare total vs failed; both versions should appear):"
    cat "$PROBE_FILE"
}

rollback() {
    log "Undoing the last promotion..."
    kubectl argo rollouts undo "$ROLLOUT" -n "$NAMESPACE"
    kubectl argo rollouts status "$ROLLOUT" -n "$NAMESPACE" --timeout 5m
}

case "${1:-status}" in
    status)
        status
        ;;
    preview)
        preview
        ;;
    promote)
        promote
        ;;
    rollback)
        rollback
        ;;
    watch)
        kubectl argo rollouts get rollout "$ROLLOUT" -n "$NAMESPACE" --watch
        ;;
    url)
        app_url
        ;;
    *)
        echo "Usage: $0 {status|preview|promote|rollback|watch|url}" >&2
        exit 1
        ;;
esac
