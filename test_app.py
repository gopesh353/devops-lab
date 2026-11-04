import os
import requests
import pytest
from dotenv import load_dotenv

load_dotenv()

BASE_URL = os.getenv("APP_URL", "http://localhost:8000")

def test_health():
    """Verify live server health endpoint."""
    try:
        res = requests.get(f"{BASE_URL}/health", timeout=5)
    except requests.exceptions.ConnectionError:
        pytest.fail(f"Server is down at {BASE_URL}")

    assert res.status_code == 200
    assert res.json().get("status") == "healthy"

def test_ui():
    """Verify live web UI is served."""
    try:
        res = requests.get(f"{BASE_URL}/", timeout=5)
    except requests.exceptions.ConnectionError:
        pytest.fail(f"Server is down at {BASE_URL}")

    assert res.status_code == 200
    assert "Gemini AI Chatbot" in res.text

def test_empty_message():
    """Verify server rejects empty input."""
    try:
        res = requests.post(f"{BASE_URL}/chat", json={"message": "   "}, timeout=5)
    except requests.exceptions.ConnectionError:
        pytest.fail(f"Server is down at {BASE_URL}")

    assert res.status_code == 400

def test_chat():
    """Verify live chat with Gemini API."""
    api_key = os.getenv("GEMINI_API_KEY", "")
    if not api_key:
        pytest.fail("GEMINI_API_KEY is missing in .env")

    try:
        res = requests.post(
            f"{BASE_URL}/chat",
            json={"message": "Say hello in one word"},
            timeout=65
        )
    except requests.exceptions.ConnectionError:
        pytest.fail(f"Server is down at {BASE_URL}")

    assert res.status_code == 200, f"Server error {res.status_code}: {res.text}"
    data = res.json()
    assert "GEMINI_API_KEY is not configured" not in data.get("reply", "")
    assert len(data.get("reply", "").strip()) > 0
    print(f"\nAI Reply: {data.get('reply')}")

if __name__ == "__main__":
    import sys
    sys.exit(pytest.main(["-v", "-s", "-p", "no:warnings", __file__]))
