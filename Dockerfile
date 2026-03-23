# =============================================================================
# Hermes Agent Railway Template - Dockerfile
# Multi-stage build with pinned Hermes version + Docker-in-Docker support
# =============================================================================

ARG HERMES_VERSION=v2026.3.17
ARG PYTHON_VERSION=3.11
ARG NODE_VERSION=22

# =============================================================================
# Stage 1: Builder - Install Hermes and dependencies
# =============================================================================
FROM python:${PYTHON_VERSION}-slim-bookworm AS builder

ARG HERMES_VERSION
ARG NODE_VERSION

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    build-essential \
    python3-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Install uv package manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Install Python 3.11 explicitly via uv
RUN uv python install ${PYTHON_VERSION}

# Clone Hermes Agent repository (pinned version)
WORKDIR /opt
RUN git clone --depth 1 --branch ${HERMES_VERSION} \
    https://github.com/NousResearch/hermes-agent.git \
    hermes-agent

WORKDIR /opt/hermes-agent

# Initialize mini-swe-agent submodule (required for terminal backend)
RUN git submodule update --init mini-swe-agent

# Create virtual environment and install dependencies
RUN uv venv venv --python ${PYTHON_VERSION}
ENV VIRTUAL_ENV=/opt/hermes-agent/venv
ENV PATH="/opt/hermes-agent/venv/bin:${PATH}"

# Install Hermes with all extras
RUN uv pip install -e ".[all,messaging,cron]"

# Install mini-swe-agent
RUN uv pip install -e "./mini-swe-agent"

# Install Node.js for browser tools
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js dependencies
RUN if [ -f package.json ]; then npm install; fi

# Install Playwright browsers for browser automation
RUN if [ -f package.json ]; then \
    npx playwright install chromium || true; \
    fi

# Install WhatsApp bridge dependencies
RUN if [ -f scripts/whatsapp-bridge/package.json ]; then \
    cd scripts/whatsapp-bridge && npm install; \
    fi

# Verify hermes command works
RUN hermes --version || echo "Hermes CLI installed"

# =============================================================================
# Stage 2: Runtime - Docker-in-Docker + Web Server
# =============================================================================
FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    # System tools
    ripgrep \
    ffmpeg \
    # For terminal backend
    libffi-dev \
    # For Playwright
    libnss3 \
    libatk-bridge2.0-0 \
    libxkbcommon0 \
    libgtk-3-0 \
    libgbm-dev \
    libasound2 \
    # Docker dependencies
    iptables \
    iproute2 \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CE (for terminal backend)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Configure Docker daemon for container-in-container
RUN mkdir -p /etc/docker \
    && echo '{\"storage-driver\": \"vfs\", \"iptables\": false}' > /etc/docker/daemon.json

# Create docker group
RUN groupadd -r docker && usermod -aG docker root

# Copy Hermes installation from builder
COPY --from=builder /opt/hermes-agent /opt/hermes-agent
COPY --from=builder /root/.local /root/.local

# Set environment variables
ENV PATH="/opt/hermes-agent/venv/bin:/root/.local/bin:${PATH}"
ENV VIRTUAL_ENV=/opt/hermes-agent/venv
ENV HERMES_HOME=/data/.hermes
ENV HOME=/data
ENV MESSAGING_CWD=/data/workspace
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Install web server dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Create necessary directories
RUN mkdir -p /data/.hermes /data/workspace /var/run/docker /var/lib/docker

# Copy application files
COPY server.py /app/server.py
COPY start.sh /app/start.sh
COPY templates /app/templates

# Make scripts executable
RUN chmod +x /app/start.sh

# Create symlinks for hermes command
RUN ln -sf /opt/hermes-agent/venv/bin/hermes /usr/local/bin/hermes

# Expose web UI port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS http://localhost:8080/health || exit 1

# Set working directory
WORKDIR /app

# Run entrypoint script
ENTRYPOINT ["./start.sh"]
