# Size-optimized multi-stage build for Railway
FROM python:3.10-slim as builder

WORKDIR /app

# Install minimal build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install with minimal bloat
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    # Remove unnecessary files but keep core packages
    find /usr/local/lib/python3.10/site-packages -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/python3.10/site-packages -name "test" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/python3.10/site-packages -name "docs" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/python3.10/site-packages -name "examples" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/python3.10/site-packages -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true && \
    rm -rf /root/.cache /tmp/*

# Production stage - optimized runtime
FROM python:3.10-slim

WORKDIR /app

# Install only essential runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy only the essential Python packages
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages

# Copy application code
COPY . .

# Create directories and final cleanup
RUN mkdir -p faiss_index && \
    # Remove Python cache files
    find . -name "*.pyc" -delete && \
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true && \
    # Remove unnecessary documentation
    find /usr/local/lib/python3.10/site-packages -name "README*" -delete 2>/dev/null || true

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]