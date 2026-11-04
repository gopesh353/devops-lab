#!/bin/bash
set -e

echo "=================================================="
echo " Kubernetes Continuous Deployment: Gemini Chatbot "
echo "=================================================="

# 1. Check kubectl connectivity
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "[ERROR] Cannot connect to Kubernetes cluster. Ensure Minikube is running with 'minikube start'."
    exit 1
fi

# 2. Update secret with live GEMINI_API_KEY from .env if present
if [ -f ".env" ]; then
    API_KEY=$(grep '^GEMINI_API_KEY=' .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" || true)
    if [ -n "$API_KEY" ]; then
        echo "[INFO] Creating/Updating chatbot-secret from .env..."
        kubectl create secret generic chatbot-secret \
            --from-literal=GEMINI_API_KEY="$API_KEY" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
fi

# 3. Apply manifests
echo "[INFO] Applying ConfigMap..."
kubectl apply -f k8s/configmap.yaml

echo "[INFO] Applying Deployment..."
kubectl apply -f k8s/deployment.yaml

echo "[INFO] Applying Service..."
kubectl apply -f k8s/service.yaml

# 4. Wait for rollout
echo "[INFO] Waiting for deployment rollout to complete..."
kubectl rollout status deployment/chatbot-deployment --timeout=90s

echo "=================================================="
echo " Kubernetes Deployment SUCCEEDED!"
echo " Deployment Replicas:"
kubectl get deployment chatbot-deployment
echo ""
echo " Running Pods:"
kubectl get pods -l app=gemini-chatbot
echo ""
echo " Service Endpoint:"
kubectl get svc chatbot-service
echo "=================================================="
