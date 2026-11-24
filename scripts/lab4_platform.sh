#!/usr/bin/env bash
set -euo pipefail

# Lab 4 platform bootstrap. Everything here is idempotent: run it again after a
# reboot to bring the same local platform back.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export PATH="$HOME/.local/bin:$PATH"

log() { echo "[platform] $*"; }

start_minikube() {
    if ! minikube status >/dev/null 2>&1; then
        log "Starting Minikube..."
        minikube start --driver=docker
    fi
    kubectl wait --for=condition=Ready node/minikube --timeout=300s >/dev/null
}

enable_ingress() {
    log "Enabling the ingress addon..."
    minikube addons enable ingress >/dev/null
    kubectl wait --namespace ingress-nginx \
        --for=condition=available deployment/ingress-nginx-controller \
        --timeout=300s >/dev/null
}

install_argocd() {
    if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        log "Argo CD is already installed."
        return
    fi
    log "Installing Argo CD..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    # Server-side apply avoids the client-side annotation size limit on the
    # large Argo CD CRDs.
    kubectl apply --server-side --force-conflicts -n argocd -f \
        https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >/dev/null
    kubectl wait --namespace argocd \
        --for=condition=available deployment/argocd-server \
        --timeout=600s >/dev/null

    # Refresh Git every 30 seconds instead of the default 3 minutes, so the
    # GitOps demos react quickly to local commits.
    kubectl -n argocd patch configmap argocd-cm --type merge \
        -p '{"data":{"timeout.reconciliation":"30s"}}' >/dev/null
    kubectl -n argocd rollout restart statefulset argocd-application-controller >/dev/null
    kubectl -n argocd rollout status statefulset argocd-application-controller \
        --timeout=300s >/dev/null
}

install_rollouts() {
    if kubectl get deployment argo-rollouts -n argo-rollouts >/dev/null 2>&1; then
        log "Argo Rollouts is already installed."
    else
        log "Installing Argo Rollouts..."
        kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f - >/dev/null
        kubectl apply --server-side --force-conflicts -n argo-rollouts -f \
            https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml >/dev/null
        kubectl wait --namespace argo-rollouts \
            --for=condition=available deployment/argo-rollouts \
            --timeout=600s >/dev/null
    fi

    if ! command -v kubectl-argo-rollouts >/dev/null 2>&1; then
        log "Installing the kubectl argo rollouts plugin..."
        mkdir -p "$HOME/.local/bin"
        curl -sL -o "$HOME/.local/bin/kubectl-argo-rollouts" \
            https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
        chmod +x "$HOME/.local/bin/kubectl-argo-rollouts"
    fi
}

install_prometheus() {
    log "Installing in-cluster Prometheus..."
    kubectl apply -f k8s/platform/prometheus.yaml >/dev/null
    kubectl wait --namespace monitoring \
        --for=condition=available deployment/prometheus \
        --timeout=300s >/dev/null
}

start_git_mirror() {
    log "Publishing this repository over a local Git smart-HTTP mirror..."
    local mirror="/tmp/opencode/devops-lab.git"
    local branch
    branch=$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)
    mkdir -p /tmp/opencode/cgi-bin

    # git http-backend gives Argo CD the smart protocol (go-git needs it for
    # shallow clones); a plain file server only speaks the dumb protocol.
    cat > /tmp/opencode/cgi-bin/git-http-backend <<'EOF'
#!/bin/sh
export GIT_PROJECT_ROOT=/tmp/opencode
export GIT_HTTP_EXPORT_ALL=1
exec git http-backend
EOF
    chmod +x /tmp/opencode/cgi-bin/git-http-backend

    if [ ! -d "$mirror" ]; then
        git clone --bare "$ROOT_DIR" "$mirror" >/dev/null 2>&1
    fi
    git -C "$ROOT_DIR" push "$mirror" "$branch:main" --force >/dev/null
    git -C "$mirror" symbolic-ref HEAD refs/heads/main
    git -C "$mirror" update-server-info

    pkill -f "http.server 9418" >/dev/null 2>&1 || true
    sleep 1
    (cd /tmp/opencode && nohup python3 -m http.server 9418 --cgi --bind 0.0.0.0 \
        --directory /tmp/opencode > /tmp/opencode/git-http.log 2>&1 &)
    sleep 1
    git ls-remote \
        "http://127.0.0.1:9418/cgi-bin/git-http-backend/devops-lab.git" >/dev/null
    log "Git mirror ready: http://host.minikube.internal:9418/cgi-bin/git-http-backend/devops-lab.git"
}

case "${1:-all}" in
    all)
        start_minikube
        enable_ingress
        install_argocd
        install_rollouts
        install_prometheus
        start_git_mirror
        ;;
    git-mirror)
        start_git_mirror
        ;;
    status)
        kubectl get nodes
        kubectl get applications -n argocd 2>/dev/null || true
        kubectl get pods -n argocd 2>/dev/null || true
        kubectl get pods -n argo-rollouts 2>/dev/null || true
        kubectl get pods -n monitoring 2>/dev/null || true
        ;;
    *)
        echo "Usage: $0 {all|git-mirror|status}" >&2
        exit 1
        ;;
esac

echo
echo "Platform ready."
echo "Argo CD UI:   kubectl port-forward svc/argocd-server -n argocd 8081:443"
echo "Argo CD pass: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo "Prometheus:   kubectl port-forward svc/prometheus -n monitoring 9090:9090"
echo "Ingress:      kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8085:80"
