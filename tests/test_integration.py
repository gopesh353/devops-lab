"""Integration tests against a running chatbot server.

Jenkins starts the app on port 8010 and runs these tests before allowing a
deployment. They deliberately avoid the real Gemini call so the gate is fast
and deterministic.
"""
import os

import requests

BASE_URL = os.getenv("APP_URL", "http://127.0.0.1:8010").rstrip("/")


def get(path):
    return requests.get(f"{BASE_URL}{path}", timeout=5)


def test_health_endpoint():
    response = get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "healthy"
    assert body["version"]
    assert response.headers.get("X-App-Version") == body["version"]


def test_ui_is_served():
    response = get("/")
    assert response.status_code == 200
    assert "Gemini AI Chatbot" in response.text


def test_features_endpoint():
    response = get("/api/features")
    assert response.status_code == 200
    assert "beta_summarizer" in response.json()


def test_metrics_endpoint():
    response = get("/metrics")
    assert response.status_code == 200
    assert "http_requests_total" in response.text


def test_empty_message_is_rejected():
    response = requests.post(f"{BASE_URL}/chat", json={"message": "  "}, timeout=5)
    assert response.status_code == 400
