# Ultra-minimal multi-stage build for size reduction
FROM python:3.10-alpine as builder

WORKDIR /app

# Install minimal build dependencies
RUN apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    g++ \
    && rm -rf /var/cache/apk/*

# Copy requirements
COPY requirements.txt .

# Install with aggressive cleanup
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    # Aggressive cleanup - remove everything non-essential
    find /usr/local/lib/python3.10/site-packages -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/python3.10/site-packages -name "test" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/python3.10/site-packages -name "docs" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/python3.10/site-packages -name "examples" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/python3.10/site-packages -name "README*" -delete 2>/dev/null || true && \
    find /usr/local/lib/python3.10/site-packages -name "*.md" -delete 2>/dev/null || true && \
    find /usr/local/lib/python3.10/site-packages -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true && \
    # Remove cache and temporary files
    rm -rf /root/.cache /tmp/* /var/tmp/* && \
    # Strip binaries
    find /usr/local -type f -executable -exec strip --strip-unneeded {} \; 2>/dev/null || true

# Production stage - minimal Alpine
FROM python:3.10-alpine

WORKDIR /app

# Install only essential runtime dependencies
RUN apk add --no-cache libgomp && \
    rm -rf /var/cache/apk/*

# Copy only essential Python packages
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY . .

# Create directories and final cleanup
RUN mkdir -p faiss_index && \
    # Remove Python cache files
    find . -name "*.pyc" -delete && \
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

EXPOSE 8000

# Use python module approach for reliability
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]