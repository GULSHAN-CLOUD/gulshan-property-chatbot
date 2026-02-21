# Ultra-aggressive size optimization using Alpine Linux
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

# Install Python packages with aggressive cleanup
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    # Aggressive cleanup
    find /usr/local -depth \
        \( \
        \( -type d -a \( -name test -o -name tests -o -name '__pycache__' \) \) \
        -o \
        \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.dist-info' \) \) \
        \) -exec rm -rf '{}' + && \
    rm -rf /root/.cache /tmp/* /var/tmp/* && \
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

# Copy only necessary Python packages
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

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

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]