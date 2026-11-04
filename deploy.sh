#!/bin/bash
set -e

# 0. Load environment variables if .env exists
if [ -f ".env" ]; then
    echo "[INFO] Loading .env variables..."
    export $(grep -v '^#' .env | xargs -d '\n') 2>/dev/null || true
fi

PORT=${APP_PORT:-8000}
PID_FILE=".server.pid"
LOG_FILE="app.log"

echo "=========================================="
echo " Starting Deployment: FastAPI Gemini Bot "
echo " Target Port: $PORT"
echo "=========================================="

# 1. Stop existing instance if running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[INFO] Stopping existing process (PID: $OLD_PID)..."
        kill "$OLD_PID" || true
        sleep 2
    fi
    rm -f "$PID_FILE"
fi

# Fallback: check if port is in use
if lsof -ti:$PORT >/dev/null 2>&1; then
    echo "[INFO] Freeing port $PORT..."
    fuser -k ${PORT}/tcp 2>/dev/null || kill $(lsof -ti:$PORT) 2>/dev/null || true
    sleep 1
fi

# 2. Activate virtual environment if available
if [ -d ".venv" ]; then
    echo "[INFO] Using virtual environment (.venv)..."
    PYTHON_BIN=".venv/bin/python3"
    UVICORN_BIN=".venv/bin/uvicorn"
else
    PYTHON_BIN="python3"
    UVICORN_BIN="uvicorn"
fi

# 3. Start application in background
echo "[INFO] Starting application..."
nohup $UVICORN_BIN app:app --host 0.0.0.0 --port $PORT > "$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "$NEW_PID" > "$PID_FILE"
echo "[INFO] Application started with PID: $NEW_PID"

# 4. Health Check / Smoke Test
echo "[INFO] Performing health check on http://127.0.0.1:$PORT/health..."
MAX_RETRIES=10
COUNT=0
HEALTHY=false

while [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 1
    COUNT=$((COUNT + 1))
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$PORT/health || echo "failed")
    if [ "$STATUS" = "200" ]; then
        HEALTHY=true
        break
    fi
    echo "[RETRY $COUNT/$MAX_RETRIES] Waiting for service..."
done

if [ "$HEALTHY" = true ]; then
    echo "=========================================="
    echo " Deployment SUCCESSFUL!"
    echo " App URL: http://localhost:$PORT"
    echo " Health Check: 200 OK"
    echo "=========================================="
    exit 0
else
    echo "=========================================="
    echo " Deployment FAILED! Health check timed out."
    echo " Recent logs:"
    tail -n 20 "$LOG_FILE"
    echo "=========================================="
    exit 1
fi
