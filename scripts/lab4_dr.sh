#!/usr/bin/env bash
set -euo pipefail

# Lab 4 disaster recovery for a stateless service.
# The backup is the declarative manifest (the app has no database); the secret
# lives in Vault and is recreated by lab4_secrets.sh. Recovery is measured.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export PATH="$HOME/.local/bin:$PATH"

NAMESPACE="chatbot"
DR_NAMESPACE="chatbot-dr"
NODE_PORT="30090"
BACKUP_DIR="$ROOT_DIR/backups"
ARTIFACT_DIR="$ROOT_DIR/dr-artifacts"
mkdir -p "$BACKUP_DIR" "$ARTIFACT_DIR"

log() { echo "[dr] $*"; }

app_url() { echo "http://$(minikube ip):${NODE_PORT}"; }

backup() {
    local stamp file
    stamp=$(date +%Y%m%d-%H%M%S)
    file="$BACKUP_DIR/chatbot-$stamp.yaml"
    cp k8s/gitops/bluegreen/all.yaml "$file"
    echo "$file" > "$BACKUP_DIR/latest.txt"

    # Snapshot the live objects too, as evidence of what existed at backup time.
    kubectl get rollout,service,configmap -n "$NAMESPACE" -o yaml \
        > "$BACKUP_DIR/chatbot-live-$stamp.yaml" 2>/dev/null || true

    log "Backup written to $file"
    kubectl get rollout,service,configmap -n "$NAMESPACE" 2>/dev/null || true
}

drill() {
    local backup_file
    backup_file=$(cat "$BACKUP_DIR/latest.txt" 2>/dev/null || true)
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        echo "No backup found. Run: $0 backup" >&2
        exit 1
    fi

    local backup_epoch disaster_epoch start ready rto rpo
    backup_epoch=$(stat -c %Y "$backup_file")

    log "Removing the Argo CD Application so it does not recreate the primary namespace..."
    kubectl delete application chatbot-bluegreen -n argocd --ignore-not-found

    start=$(date +%s)
    disaster_epoch=$start
    log "Simulating a disaster: deleting namespace $NAMESPACE..."
    kubectl delete namespace "$NAMESPACE" --wait=true --timeout=180s

    log "Restoring the manifest into $DR_NAMESPACE..."
    kubectl create namespace "$DR_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    python3 - "$backup_file" "$DR_NAMESPACE" > /tmp/opencode/chatbot-dr.yaml <<'PY'
import sys
source, namespace = sys.argv[1], sys.argv[2]
documents = open(source, encoding="utf-8").read().split("\n---\n")
kept = []
for document in documents:
    if "kind: Namespace" in document:
        continue
    kept.append(document.replace("namespace: chatbot\n", f"namespace: {namespace}\n"))
print("\n---\n".join(kept))
PY
    kubectl apply -f /tmp/opencode/chatbot-dr.yaml

    log "Recreating the API key from Vault in $DR_NAMESPACE..."
    scripts/lab4_secrets.sh sync

    log "Waiting for the restored Rollout to become healthy..."
    kubectl argo rollouts status chatbot -n "$DR_NAMESPACE" --timeout 5m

    ready=$(date +%s)
    rto=$((ready - start))
    rpo=$((disaster_epoch - backup_epoch))

    curl -s "$(app_url)/health" | tee "$ARTIFACT_DIR/dr-health.json"
    echo
    {
        echo "backup_file=$backup_file"
        echo "backup_time=$(date -u -d @"$backup_epoch" +%Y-%m-%dT%H:%M:%SZ)"
        echo "disaster_time=$(date -u -d @"$disaster_epoch" +%Y-%m-%dT%H:%M:%SZ)"
        echo "recovered_time=$(date -u -d @"$ready" +%Y-%m-%dT%H:%M:%SZ)"
        echo "rto_seconds=$rto"
        echo "rpo_seconds=$rpo"
        echo "traffic_served_from=$DR_NAMESPACE (same NodePort $NODE_PORT)"
    } | tee "$ARTIFACT_DIR/rto.txt"

    log "Failback with: $0 failback"
}

failback() {
    log "Removing $DR_NAMESPACE so NodePort $NODE_PORT is free..."
    kubectl delete namespace "$DR_NAMESPACE" --wait=true --timeout=180s

    log "Recreating the GitOps Application and syncing the primary..."
    kubectl apply -f gitops/argocd-apps.yaml >/dev/null
    kubectl patch application chatbot-bluegreen -n argocd --type merge \
        -p '{"operation":{"sync":{}}}' >/dev/null 2>&1 || true

    for _ in $(seq 1 60); do
        sync=$(kubectl get application chatbot-bluegreen -n argocd \
            -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
        health=$(kubectl get application chatbot-bluegreen -n argocd \
            -o jsonpath='{.status.health.status}' 2>/dev/null || true)
        if [ "$sync" = "Synced" ] && [ "$health" = "Healthy" ]; then
            break
        fi
        sleep 5
    done

    kubectl argo rollouts status chatbot -n "$NAMESPACE" --timeout 5m
    curl -s "$(app_url)/health" | tee "$ARTIFACT_DIR/failback-health.json"
}

status() {
    echo "Latest backup: $(cat "$BACKUP_DIR/latest.txt" 2>/dev/null || echo none)"
    echo
    kubectl get namespaces | grep -E 'chatbot|NAME' || true
    echo
    printf 'Health on NodePort %s: ' "$NODE_PORT"
    curl -s --max-time 3 "$(app_url)/health" || echo "unreachable"
    echo
    cat "$ARTIFACT_DIR/rto.txt" 2>/dev/null || true
}

case "${1:-status}" in
    backup)
        backup
        ;;
    drill)
        drill
        ;;
    failback)
        failback
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {backup|drill|failback|status}" >&2
        exit 1
        ;;
esac
