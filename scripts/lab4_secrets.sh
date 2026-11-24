#!/usr/bin/env bash
set -euo pipefail

# Vault (file storage on the host) -> Kubernetes Secret. The API key is never
# written to Git and is never printed by this script.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
umask 077

VAULT_CONTAINER="vault-lab4"
VAULT_ADDR_IN="http://127.0.0.1:8200"
INIT_FILE=".vault-init.json"

log() { echo "[secrets] $*"; }

vault_exec() {
    docker exec -e VAULT_ADDR="$VAULT_ADDR_IN" "$@"
}

vault_token() {
    python3 -c 'import json; print(json.load(open(".vault-init.json"))["root_token"])'
}

vault_unseal_key() {
    python3 -c 'import json; print(json.load(open(".vault-init.json"))["unseal_keys_b64"][0])'
}

start_vault() {
    if docker ps -a --format '{{.Names}}' | grep -qx "$VAULT_CONTAINER"; then
        docker start "$VAULT_CONTAINER" >/dev/null
    else
        log "Starting Vault..."
        docker run -d --name "$VAULT_CONTAINER" \
            --cap-add=IPC_LOCK \
            -p 8200:8200 \
            -v vault-lab4-data:/vault/data \
            -v "$ROOT_DIR/vault/config.hcl:/vault/config/config.hcl:ro" \
            hashicorp/vault:1.18.3 \
            server -config=/vault/config/config.hcl >/dev/null
    fi

    for _ in $(seq 1 30); do
        if curl -s http://127.0.0.1:8200/v1/sys/health >/dev/null; then
            return 0
        fi
        sleep 1
    done
    echo "Vault did not become reachable." >&2
    exit 1
}

init_vault() {
    if [ ! -f "$INIT_FILE" ]; then
        log "Initializing Vault (one key share, one threshold)..."
        vault_exec "$VAULT_CONTAINER" vault operator init \
            -key-shares=1 -key-threshold=1 -format=json > "$INIT_FILE"
    fi

    local status_json
    status_json=$(vault_exec "$VAULT_CONTAINER" vault status -format=json 2>/dev/null || true)
    if ! echo "$status_json" | grep -q '"initialized": true'; then
        echo "Vault is not initialized. Remove .vault-init.json and the vault-lab4-data volume to start over." >&2
        exit 1
    fi
    if echo "$status_json" | grep -q '"sealed": true'; then
        log "Unsealing Vault..."
        vault_exec "$VAULT_CONTAINER" vault operator unseal "$(vault_unseal_key)" >/dev/null
    fi
    vault_exec "$VAULT_CONTAINER" vault secrets enable -path=secret kv-v2 >/dev/null 2>&1 || true
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
        -e VAULT_ADDR="$VAULT_ADDR_IN" \
        -e VAULT_TOKEN="$(vault_token)" \
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
    vault_exec -e VAULT_TOKEN="$(vault_token)" "$VAULT_CONTAINER" \
        vault kv get -field=GEMINI_API_KEY secret/chatbot | tr -d '\n' | wc -c
    echo
    kubectl get secret chatbot-secret -n chatbot 2>/dev/null || true
    kubectl get secret chatbot-secret -n chatbot-canary 2>/dev/null || true
    kubectl get secret chatbot-secret -n chatbot-dr 2>/dev/null || true
}

case "${1:-start}" in
    start)
        start_vault
        init_vault
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
        echo "Vault root token (local lab only):"
        vault_token
        ;;
    *)
        echo "Usage: $0 {start|sync|status|token}" >&2
        exit 1
        ;;
esac
