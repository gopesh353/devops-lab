import os
import requests
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

app = FastAPI(title="Gemini AI Chatbot", version="1.0.0")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

class ChatRequest(BaseModel):
    message: str
    history: list[dict] = []
    api_key: str | None = None

class ChatResponse(BaseModel):
    reply: str
    model: str

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "fastapi-gemini-chatbot",
        "version": "1.0.0"
    }

@app.get("/", response_class=HTMLResponse)
def index():
    return """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Lab 1 - Gemini AI Chatbot</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        body { background: #0f172a; color: #f8fafc; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 1rem; }
        .chat-card { background: #1e293b; width: 100%; max-width: 650px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); overflow: hidden; display: flex; flex-direction: column; height: 85vh; border: 1px solid #334155; }
        .header { background: #0ea5e9; padding: 1rem 1.5rem; display: flex; justify-content: space-between; align-items: center; }
        .header h1 { font-size: 1.15rem; font-weight: 600; color: #fff; }
        .header-controls { display: flex; align-items: center; gap: 0.5rem; }
        .btn-clear { background: rgba(255,255,255,0.15); color: white; border: 1px solid rgba(255,255,255,0.3); border-radius: 4px; padding: 0.25rem 0.5rem; font-size: 0.75rem; cursor: pointer; }
        .btn-clear:hover { background: rgba(255,255,255,0.25); }
        .status-badge { background: #10b981; color: white; padding: 0.2rem 0.6rem; border-radius: 20px; font-size: 0.75rem; font-weight: bold; }
        .key-input { padding: 0.25rem 0.5rem; border-radius: 4px; border: none; background: rgba(255,255,255,0.2); color: white; font-size: 0.75rem; outline: none; width: 130px; }
        .key-input::placeholder { color: rgba(255,255,255,0.7); }
        .chat-box { flex: 1; padding: 1.5rem; overflow-y: auto; display: flex; flex-direction: column; gap: 1rem; }
        .msg { max-width: 80%; padding: 0.75rem 1rem; border-radius: 8px; font-size: 0.95rem; line-height: 1.4; word-wrap: break-word; }
        .user-msg { background: #0284c7; color: white; align-self: flex-end; border-bottom-right-radius: 2px; }
        .bot-msg { background: #334155; color: #e2e8f0; align-self: flex-start; border-bottom-left-radius: 2px; }
        .input-bar { display: flex; padding: 1rem; background: #0f172a; gap: 0.5rem; border-top: 1px solid #334155; }
        .input-bar input { flex: 1; padding: 0.75rem 1rem; border-radius: 6px; border: 1px solid #334155; background: #1e293b; color: white; font-size: 0.95rem; outline: none; }
        .input-bar input:focus { border-color: #0ea5e9; }
        .input-bar button { padding: 0.75rem 1.25rem; background: #0ea5e9; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; }
        .input-bar button:hover { background: #0284c7; }
        .footer-note { text-align: center; font-size: 0.75rem; color: #64748b; padding: 0.4rem; background: #0f172a; }
    </style>
</head>
<body>
    <div class="chat-card">
        <div class="header">
            <h1>Gemini AI Chatbot</h1>
            <div class="header-controls">
                <button onclick="clearChat()" class="btn-clear" title="Clear Chat Memory">Clear</button>
                <input type="password" id="api-key-input" class="key-input" placeholder="API Key (optional)" title="Optional: Set Gemini API Key" />
                <span class="status-badge" id="health-status">Checking...</span>
            </div>
        </div>
        <div class="chat-box" id="chat-box">
            <div class="msg bot-msg">Hello! I am your AI assistant deployed via Jenkins CI/CD. How can I help you today?</div>
        </div>
        <div class="input-bar">
            <input type="text" id="user-input" placeholder="Type a message..." onkeydown="if(event.key==='Enter') sendMessage()" />
            <button onclick="sendMessage()">Send</button>
        </div>
        <div class="footer-note">CI/CD Automated Deployment • DevOps Lab 1</div>
    </div>

    <script>
        let conversationHistory = [];

        const keyInput = document.getElementById('api-key-input');
        if (localStorage.getItem('gemini_api_key')) {
            keyInput.value = localStorage.getItem('gemini_api_key');
        }
        keyInput.addEventListener('change', () => {
            localStorage.setItem('gemini_api_key', keyInput.value.trim());
        });

        function clearChat() {
            conversationHistory = [];
            const chatBox = document.getElementById('chat-box');
            chatBox.innerHTML = '<div class="msg bot-msg">Conversation history cleared! How can I help you?</div>';
        }

        fetch('/health')
            .then(res => res.json())
            .then(data => {
                document.getElementById('health-status').innerText = 'Online (' + data.version + ')';
            })
            .catch(() => {
                const badge = document.getElementById('health-status');
                badge.innerText = 'Offline';
                badge.style.background = '#ef4444';
            });

        async function sendMessage() {
            const input = document.getElementById('user-input');
            const message = input.value.trim();
            if (!message) return;

            const chatBox = document.getElementById('chat-box');
            
            // Append user message
            const userDiv = document.createElement('div');
            userDiv.className = 'msg user-msg';
            userDiv.innerText = message;
            chatBox.appendChild(userDiv);
            input.value = '';
            chatBox.scrollTop = chatBox.scrollHeight;

            // Loading state
            const loadingDiv = document.createElement('div');
            loadingDiv.className = 'msg bot-msg';
            loadingDiv.innerText = 'Thinking...';
            chatBox.appendChild(loadingDiv);
            chatBox.scrollTop = chatBox.scrollHeight;

            const clientApiKey = keyInput.value.trim() || localStorage.getItem('gemini_api_key') || null;

            try {
                const res = await fetch('/chat', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        message: message,
                        history: conversationHistory,
                        api_key: clientApiKey
                    })
                });
                const data = await res.json();
                const replyText = data.reply || (data.detail ? `Error: ${data.detail}` : 'No response');
                loadingDiv.innerText = replyText;

                // Save to conversation memory if successful
                if (data.reply && !data.reply.startsWith('[Notice]')) {
                    conversationHistory.push({ role: 'user', text: message });
                    conversationHistory.push({ role: 'model', text: data.reply });
                }
            } catch (err) {
                loadingDiv.innerText = 'Failed to connect to backend service.';
            }
            chatBox.scrollTop = chatBox.scrollHeight;
        }
    </script>
</body>
</html>
"""

@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest):
    if not request.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    if request.api_key is not None:
        api_key = request.api_key.strip()
    else:
        api_key = os.getenv("GEMINI_API_KEY", "") or GEMINI_API_KEY

    if not api_key:
        return ChatResponse(
            reply="[Notice] GEMINI_API_KEY is not configured on the server. Please set the GEMINI_API_KEY environment variable or enter it above.",
            model="mock/unconfigured"
        )

    model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")
    endpoint = GEMINI_URL.format(model=model) + f"?key={api_key}"

    # Build multi-turn conversation contents for Gemini API
    raw_contents = []
    for item in request.history:
        role = item.get("role", "user")
        if role not in ["user", "model"]:
            role = "user" if role in ["user", "human"] else "model"

        text = ""
        if "parts" in item and isinstance(item["parts"], list) and item["parts"]:
            text = item["parts"][0].get("text", "")
        else:
            text = item.get("text") or item.get("content") or ""

        text = text.strip()
        if text:
            raw_contents.append({
                "role": role,
                "parts": [{"text": text}]
            })

    # Ensure conversation starts with user turn
    while raw_contents and raw_contents[0]["role"] != "user":
        raw_contents.pop(0)

    # Merge consecutive identical roles to adhere to Gemini API schema
    contents = []
    for item in raw_contents:
        if contents and contents[-1]["role"] == item["role"]:
            contents[-1]["parts"].append(item["parts"][0])
        else:
            contents.append(item)

    # Append current user message
    if contents and contents[-1]["role"] == "user":
        contents[-1]["parts"].append({"text": request.message.strip()})
    else:
        contents.append({
            "role": "user",
            "parts": [{"text": request.message.strip()}]
        })

    payload = {
        "contents": contents
    }

    try:
        response = requests.post(endpoint, json=payload, timeout=60)
        response.raise_for_status()
        data = response.json()
        
        candidates = data.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            if parts:
                text = parts[0].get("text", "")
                return ChatResponse(reply=text.strip(), model=model)
                
        return ChatResponse(reply="No response generated from Gemini API.", model=model)
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=502, detail=f"Gemini API request failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
