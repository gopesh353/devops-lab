"""Fast unit tests for the chatbot API.

These tests use FastAPI's TestClient and never call the real Gemini API.
They are the first gate in the Jenkins pipeline.
"""
import os

import pytest
from fastapi.testclient import TestClient

import app as app_module

client = TestClient(app_module.app)


class FakeGeminiResponse:
    """Minimal stand-in for requests.Response."""

    def __init__(self, payload, status_code=200):
        self._payload = payload
        self.status_code = status_code

    def raise_for_status(self):
        if self.status_code >= 400:
            import requests

            raise requests.exceptions.HTTPError(f"{self.status_code} error")

    def json(self):
        return self._payload


def test_health_reports_version_and_hostname():
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "healthy"
    assert body["version"] == app_module.APP_VERSION
    assert body["hostname"]
    assert response.headers["X-App-Version"] == app_module.APP_VERSION


def test_index_page_renders_chat_ui():
    response = client.get("/")
    assert response.status_code == 200
    assert "Gemini AI Chatbot" in response.text
    assert 'id="user-input"' in response.text
    assert 'id="chat-box"' in response.text


def test_feature_flags_can_be_toggled():
    before = client.get("/api/features").json()
    assert "beta_summarizer" in before

    toggled = client.post("/api/features/beta_summarizer/toggle")
    assert toggled.status_code == 200
    assert toggled.json()["feature"] == "beta_summarizer"
    assert toggled.json()["enabled"] != before["beta_summarizer"]

    # Restore the original state for other tests.
    client.post("/api/features/beta_summarizer/toggle")


def test_unknown_feature_returns_404():
    response = client.post("/api/features/does-not-exist/toggle")
    assert response.status_code == 404


def test_empty_message_is_rejected():
    response = client.post("/chat", json={"message": "   "})
    assert response.status_code == 400


def test_chat_returns_gemini_reply(monkeypatch):
    def fake_post(url, json, timeout):
        return FakeGeminiResponse(
            {"candidates": [{"content": {"parts": [{"text": "Hello!"}]}}]}
        )

    monkeypatch.setattr(app_module.requests, "post", fake_post)
    response = client.post("/chat", json={"message": "Hi", "api_key": "test-key"})
    assert response.status_code == 200
    assert response.json()["reply"] == "Hello!"
    assert response.json()["model"] == os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")


def test_chat_upstream_failure_returns_502(monkeypatch):
    def fake_post(url, json, timeout):
        return FakeGeminiResponse({}, status_code=500)

    monkeypatch.setattr(app_module.requests, "post", fake_post)
    response = client.post("/chat", json={"message": "Hi", "api_key": "test-key"})
    assert response.status_code == 502


def test_pipeline_gate_demo():
    """Set FAIL_DEMO=1 in Jenkins to prove a red test blocks the pipeline."""
    if os.getenv("FAIL_DEMO", "").lower() in {"1", "true", "yes"}:
        pytest.fail("Intentional failure: the CI gate must stop before deployment.")
