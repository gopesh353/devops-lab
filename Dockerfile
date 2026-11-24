# Base Python Image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Optimize Python runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install application dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Build-time application version (v1 / v2 for deployment labs).
# Kept after the dependency layer so changing the version reuses the pip cache.
ARG APP_VERSION=1.0.0
ENV APP_VERSION=${APP_VERSION}

# Copy application files
COPY app.py .
COPY .env.example .

# Expose port 8000
EXPOSE 8000

# Health check to verify application readiness
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Launch FastAPI app with Uvicorn
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
