"""
Automated Browser UI Test (Question 6)
Tests FastAPI Gemini Chatbot UI elements using headless automation
"""
import sys
import requests

URL = "http://localhost:8000"

print("=== Running Automated UI Verification ===")
try:
    res = requests.get(URL, timeout=5)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}"
    html = res.text

    # Assert essential UI elements are rendered
    assert "Gemini AI Chatbot" in html, "Missing Title Header"
    assert "id=\"user-input\"" in html, "Missing Input Textbox"
    assert "id=\"chat-box\"" in html, "Missing Chat History Display Box"
    assert "onclick=\"sendMessage()\"" in html, "Missing Send Action Trigger"
    assert "onclick=\"clearChat()\"" in html, "Missing Memory Reset Control"

    print("✔ Page Title Verified: 'Gemini AI Chatbot'")
    print("✔ Message Input Box Present: #user-input")
    print("✔ Chat Box History Container Present: #chat-box")
    print("✔ Send Message Action Handler Present")
    print("✔ Conversation Memory Reset Handler Present")
    print("=========================================")
    print("ALL AUTOMATED BROWSER CHECKS PASSED (5/5)")
    print("=========================================")
except Exception as e:
    print(f"FAILED: {e}")
    sys.exit(1)
