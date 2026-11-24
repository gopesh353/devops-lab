#!/usr/bin/env bash
set -euo pipefail

# Build the two chatbot versions and make them visible to Minikube.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

docker build --build-arg APP_VERSION=1.0.0 -t devops-chatbot:v1 .
docker build --build-arg APP_VERSION=2.0.0 -t devops-chatbot:v2 .

minikube image load devops-chatbot:v1
minikube image load devops-chatbot:v2

echo
echo "Images available inside Minikube:"
minikube image ls | grep devops-chatbot
