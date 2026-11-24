#!/usr/bin/env bash
set -euo pipefail

# Vault (dev mode, local lab only) -> Kubernetes Secret. The API key is never
# written to Git and is never printed by this script.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VAULT_CONTAINER="vault-lab4"
VAULT_HOST_ADDR="http://127.0.0.1:8201"

log() { echo "[secrets] $*"; }

vault_exec() {
    docker exec -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN=root "$@"
}

start_vault() {
    if docker ps --format '{{.Names}}' | grep -qx "$VAULT_CONTAINER"; then
        log "Vault is already running."
    else
        docker rm -f "$VAULT_CONTAINER" >/dev/null 2>&1 || true
        log "Starting Vault (dev mode)..."
        docker run -d --name "$VAULT_CONTAINER" \
            -p 8201:8200 \
            -e VAULT_DEV_ROOT_TOKEN_ID=root \
            -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
            hashicorp/vault:1.18.3 server -dev >/dev/null
    fi

    for _ in $(seq 1 30); do
        if curl -s "$VAULT_HOST_ADDR/v1/sys/health" >/dev/null; then
            return 0
        fi
        sleep 1
    done
    echo "Vault did not become reachable." >&2
    exit 1
}

read_api_key() {
    local api_key
    api_key=$(grep '^GEMINI_API_KEY=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '"' | tr -d "'" || true)
    if [ -z "$api_key" ]; then
        echo "No GEMINI_API_KEY found in .env" >&2
        exit 1
    fi
    printf '%s' "$api_key"
}

write_secret() {
    local api_key
    api_key=$(read_api_key)
    log "Writing GEMINI_API_KEY to Vault (value is not printed)..."
    printf '%s' "$api_key" | docker exec -i \
        -e VAULT_ADDR="http://127.0.0.1:8200" \
        -e VAULT_TOKEN=root \
        "$VAULT_CONTAINER" vault kv put secret/chatbot GEMINI_API_KEY=- >/dev/null
    log "Stored at secret/chatbot (length: ${#api_key})."
}

sync_kubernetes() {
    local api_key
    api_key=$(read_api_key)
    for namespace in chatbot chatbot-canary chatbot-dr; do
        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
            kubectl create secret generic chatbot-secret \
                --namespace "$namespace" \
                --from-literal=GEMINI_API_KEY="$api_key" \
                --dry-run=client -o yaml | kubectl apply -f - >/dev/null
            log "Secret chatbot-secret synced in namespace $namespace."
        fi
    done
}

status() {
    vault_exec "$VAULT_CONTAINER" vault status || true
    echo
    printf 'Vault key length: '
    vault_exec "$VAULT_CONTAINER" vault kv get -field=GEMINI_API_KEY secret/chatbot | tr -d '\n' | wc -c
    echo
    kubectl get secret chatbot-secret -n chatbot 2>/dev/null || true
    kubectl get secret chatbot-secret -n chatbot-canary 2>/dev/null || true
    kubectl get secret chatbot-secret -n chatbot-dr 2>/dev/null || true
}

case "${1:-start}" in
    start)
        start_vault
        write_secret
        sync_kubernetes
        ;;
    sync)
        write_secret
        sync_kubernetes
        ;;
    status)
        status
        ;;
    token)
        echo "Vault dev-mode root token (local lab only): root"
        ;;
    *)
        echo "Usage: $0 {start|sync|status|token}" >&2
        exit 1
        ;;
esac
