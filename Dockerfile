# Ultra-aggressive size optimization with proper executable handling
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

# Install Python packages and preserve executables
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    # Preserve uvicorn executable specifically
    cp /usr/local/bin/uvicorn /tmp/ && \
    # Aggressive cleanup but preserve executables
    find /usr/local -depth \
        \( \
        \( -type d -a \( -name test -o -name tests -o -name '__pycache__' \) \) \
        -o \
        \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.dist-info' \) \) \
        \) -not -path "/usr/local/bin/*" -exec rm -rf '{}' + && \
    rm -rf /root/.cache /tmp/* /var/tmp/* && \
    # Move uvicorn back
    mv /tmp/uvicorn /usr/local/bin/ && \
    # Remove documentation and examples
    find /usr/local/lib/python3.10/site-packages -name "README*" -delete && \
    find /usr/local/lib/python3.10/site-packages -name "EXAMPLE*" -delete && \
    find /usr/local/lib/python3.10/site-packages -name "demo" -type d -exec rm -rf {} + 2>/dev/null || true

# Production stage - minimal Alpine runtime
FROM python:3.10-alpine

WORKDIR /app

# Install only essential runtime dependencies
RUN apk add --no-cache libgomp && \
    rm -rf /var/cache/apk/*

# Copy everything from builder stage
COPY --from=builder /usr/local /usr/local

# Copy application code
COPY . .

# Create directories and clean up
RUN mkdir -p faiss_index && \
    # Remove unnecessary files
    find . -name "*.pyc" -delete && \
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true && \
    # Strip binaries to reduce size
    find /usr/local -type f -executable -exec strip --strip-unneeded {} \; 2>/dev/null || true

EXPOSE 8000

# Use python module approach to avoid path issues
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]