# Minimal Python - Zero CVE Target
# Uses Google's distroless Python base for minimal attack surface
ARG PYTHON_VERSION=3.12

# Build stage for installing dependencies
FROM python:${PYTHON_VERSION}-slim-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install pip packages here if needed
# COPY requirements.txt .
# RUN pip install --no-cache-dir -r requirements.txt

# Runtime stage - use distroless Python
FROM gcr.io/distroless/python3-debian12:nonroot

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Set environment
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PATH="/opt/venv/bin:$PATH"

# Working directory
WORKDIR /app

# Copy application (uncomment when you have an app)
# COPY --chown=nonroot:nonroot ./app /app

USER nonroot

ENTRYPOINT ["python"]
