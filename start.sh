#!/bin/bash
# =============================================================================
# Hermes Agent Railway Template - Entrypoint Script
# Handles initialization and startup of the web server and gateway
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Configuration
# =============================================================================

export HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
export HOME="${HOME:-/data}"
export MESSAGING_CWD="${MESSAGING_CWD:-/data/workspace}"
export PORT="${PORT:-8080}"
export ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"

HERMES_VERSION="v2026.3.17"
INIT_MARKER="${HERMES_HOME}/.initialized"
ENV_FILE="${HERMES_HOME}/.env"
CONFIG_FILE="${HERMES_HOME}/config.yaml"

# =============================================================================
# Setup Directories
# =============================================================================

setup_directories() {
    log_info "Setting up directories..."
    
    mkdir -p "${HERMES_HOME}"/{
        cron,
        sessions,
        logs,
        pairing,
        hooks,
        image_cache,
        audio_cache,
        memories,
        skills,
        whatsapp/session
    }
    mkdir -p "${MESSAGING_CWD}"
    mkdir -p /var/run/docker /var/lib/docker
    
    log_success "Directories created"
}

# =============================================================================
# Generate Admin Password
# =============================================================================

generate_password() {
    if [[ -z "${ADMIN_PASSWORD}" ]]; then
        ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/')
        export ADMIN_PASSWORD
        log_warn "ADMIN_PASSWORD not set. Generated random password:"
        echo ""
        echo "================================================"
        echo "  Admin Username: ${ADMIN_USERNAME}"
        echo "  Admin Password: ${ADMIN_PASSWORD}"
        echo "================================================"
        echo ""
        log_warn "Save this password! It will not be shown again."
    fi
}

# =============================================================================
# Validate Environment
# =============================================================================

validate_environment() {
    log_info "Validating environment..."
    
    local has_provider=false
    local has_platform=false
    
    # Check for LLM provider
    if [[ -n "${HERMES_OPENROUTER_API_KEY}" ]]; then
        has_provider=true
        log_success "✓ OpenRouter configured"
    fi
    
    if [[ -n "${HERMES_ANTHROPIC_API_KEY}" ]]; then
        has_provider=true
        log_success "✓ Anthropic configured"
    fi
    
    if [[ -n "${HERMES_OPENAI_API_KEY}" ]]; then
        has_provider=true
        log_success "✓ OpenAI configured"
    fi
    
    if [[ -n "${HERMES_GLM_API_KEY}" ]]; then
        has_provider=true
        log_success "✓ GLM (z.ai) configured"
    fi
    
    if [[ -n "${HERMES_KIMI_API_KEY}" ]]; then
        has_provider=true
        log_success "✓ Kimi configured"
    fi
    
    if [[ -n "${HERMES_MINIMAX_API_KEY}" ]]; then
        has_provider=true
        log_success "✓ MiniMax configured"
    fi
    
    if [[ -n "${HERMES_NOUS_PORTAL_KEY}" ]]; then
        has_provider=true
        log_success "✓ Nous Portal configured"
    fi
    
    if [[ "${has_provider}" == "false" ]]; then
        log_error "No LLM provider configured!"
        log_info "Please set at least one of:"
        log_info "  - HERMES_OPENROUTER_API_KEY"
        log_info "  - HERMES_ANTHROPIC_API_KEY"
        log_info "  - HERMES_OPENAI_API_KEY"
        log_info "  - HERMES_GLM_API_KEY"
        log_info "  - HERMES_KIMI_API_KEY"
        log_info "  - HERMES_MINIMAX_API_KEY"
        log_info "  - HERMES_NOUS_PORTAL_KEY"
        exit 1
    fi
    
    # Check for messaging platform
    if [[ -n "${HERMES_TELEGRAM_TOKEN}" ]]; then
        has_platform=true
        log_success "✓ Telegram configured"
    fi
    
    if [[ -n "${HERMES_DISCORD_TOKEN}" ]]; then
        has_platform=true
        log_success "✓ Discord configured"
    fi
    
    if [[ -n "${HERMES_SLACK_BOT_TOKEN}" ]]; then
        has_platform=true
        log_success "✓ Slack configured"
    fi
    
    if [[ "${HERMES_WHATSAPP_ENABLED}" == "true" ]]; then
        has_platform=true
        log_success "✓ WhatsApp enabled"
    fi
    
    if [[ "${has_platform}" == "false" ]]; then
        log_error "No messaging platform configured!"
        log_info "Please set at least one of:"
        log_info "  - HERMES_TELEGRAM_TOKEN"
        log_info "  - HERMES_DISCORD_TOKEN"
        log_info "  - HERMES_SLACK_BOT_TOKEN + HERMES_SLACK_APP_TOKEN"
        log_info "  - HERMES_WHATSAPP_ENABLED=true"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# =============================================================================
# Write Hermes Environment File
# =============================================================================

write_env_file() {
    log_info "Writing Hermes environment configuration..."
    
    {
        echo "# Hermes Agent Railway Template - Environment Configuration"
        echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo ""
        echo "HERMES_HOME=${HERMES_HOME}"
        echo "MESSAGING_CWD=${MESSAGING_CWD}"
        echo ""
        
        # LLM Providers
        [[ -n "${HERMES_OPENROUTER_API_KEY}" ]] && echo "OPENROUTER_API_KEY=${HERMES_OPENROUTER_API_KEY}"
        [[ -n "${HERMES_ANTHROPIC_API_KEY}" ]] && echo "ANTHROPIC_API_KEY=${HERMES_ANTHROPIC_API_KEY}"
        [[ -n "${HERMES_OPENAI_API_KEY}" ]] && echo "OPENAI_API_KEY=${HERMES_OPENAI_API_KEY}"
        [[ -n "${HERMES_GLM_API_KEY}" ]] && echo "GLM_API_KEY=${HERMES_GLM_API_KEY}"
        [[ -n "${HERMES_KIMI_API_KEY}" ]] && echo "KIMI_API_KEY=${HERMES_KIMI_API_KEY}"
        [[ -n "${HERMES_MINIMAX_API_KEY}" ]] && echo "MINIMAX_API_KEY=${HERMES_MINIMAX_API_KEY}"
        [[ -n "${HERMES_NOUS_PORTAL_KEY}" ]] && echo "NOUS_API_KEY=${HERMES_NOUS_PORTAL_KEY}"
        [[ -n "${HERMES_PROVIDER}" ]] && echo "HERMES_INFERENCE_PROVIDER=${HERMES_PROVIDER}"
        echo ""
        
        # Agent Configuration
        [[ -n "${HERMES_MODEL}" ]] && echo "LLM_MODEL=${HERMES_MODEL}"
        [[ -n "${HERMES_MAX_TOKENS}" ]] && echo "HERMES_MAX_TOKENS=${HERMES_MAX_TOKENS}"
        [[ -n "${HERMES_TEMPERATURE}" ]] && echo "HERMES_TEMPERATURE=${HERMES_TEMPERATURE}"
        [[ -n "${HERMES_MAX_ITERATIONS}" ]] && echo "HERMES_MAX_ITERATIONS=${HERMES_MAX_ITERATIONS}"
        echo ""
        
        # Telegram
        [[ -n "${HERMES_TELEGRAM_TOKEN}" ]] && echo "TELEGRAM_BOT_TOKEN=${HERMES_TELEGRAM_TOKEN}"
        [[ -n "${HERMES_TELEGRAM_ALLOWED_USERS}" ]] && echo "TELEGRAM_ALLOWED_USERS=${HERMES_TELEGRAM_ALLOWED_USERS}"
        [[ -n "${HERMES_TELEGRAM_HOME_CHANNEL}" ]] && echo "TELEGRAM_HOME_CHANNEL=${HERMES_TELEGRAM_HOME_CHANNEL}"
        [[ -n "${HERMES_TELEGRAM_ALLOW_ALL_USERS}" ]] && echo "TELEGRAM_ALLOW_ALL_USERS=${HERMES_TELEGRAM_ALLOW_ALL_USERS}"
        echo ""
        
        # Discord
        [[ -n "${HERMES_DISCORD_TOKEN}" ]] && echo "DISCORD_BOT_TOKEN=${HERMES_DISCORD_TOKEN}"
        [[ -n "${HERMES_DISCORD_ALLOWED_USERS}" ]] && echo "DISCORD_ALLOWED_USERS=${HERMES_DISCORD_ALLOWED_USERS}"
        [[ -n "${HERMES_DISCORD_HOME_CHANNEL}" ]] && echo "DISCORD_HOME_CHANNEL=${HERMES_DISCORD_HOME_CHANNEL}"
        [[ -n "${HERMES_DISCORD_ALLOW_ALL_USERS}" ]] && echo "DISCORD_ALLOW_ALL_USERS=${HERMES_DISCORD_ALLOW_ALL_USERS}"
        echo ""
        
        # Slack
        [[ -n "${HERMES_SLACK_BOT_TOKEN}" ]] && echo "SLACK_BOT_TOKEN=${HERMES_SLACK_BOT_TOKEN}"
        [[ -n "${HERMES_SLACK_APP_TOKEN}" ]] && echo "SLACK_APP_TOKEN=${HERMES_SLACK_APP_TOKEN}"
        [[ -n "${HERMES_SLACK_ALLOWED_USERS}" ]] && echo "SLACK_ALLOWED_USERS=${HERMES_SLACK_ALLOWED_USERS}"
        [[ -n "${HERMES_SLACK_HOME_CHANNEL}" ]] && echo "SLACK_HOME_CHANNEL=${HERMES_SLACK_HOME_CHANNEL}"
        [[ -n "${HERMES_SLACK_ALLOW_ALL_USERS}" ]] && echo "SLACK_ALLOW_ALL_USERS=${HERMES_SLACK_ALLOW_ALL_USERS}"
        echo ""
        
        # WhatsApp
        [[ "${HERMES_WHATSAPP_ENABLED}" == "true" ]] && echo "WHATSAPP_ENABLED=true"
        [[ -n "${HERMES_WHATSAPP_ALLOWED_USERS}" ]] && echo "WHATSAPP_ALLOWED_USERS=${HERMES_WHATSAPP_ALLOWED_USERS}"
        echo ""
        
        # Security
        [[ "${HERMES_GATEWAY_ALLOW_ALL}" == "true" ]] && echo "GATEWAY_ALLOW_ALL_USERS=true"
        echo ""
        
        # Tool API Keys
        [[ -n "${HERMES_BROWSERBASE_API_KEY}" ]] && echo "BROWSERBASE_API_KEY=${HERMES_BROWSERBASE_API_KEY}"
        [[ -n "${HERMES_BROWSERBASE_PROJECT_ID}" ]] && echo "BROWSERBASE_PROJECT_ID=${HERMES_BROWSERBASE_PROJECT_ID}"
        [[ -n "${HERMES_PARALLEL_API_KEY}" ]] && echo "PARALLEL_API_KEY=${HERMES_PARALLEL_API_KEY}"
        [[ -n "${HERMES_FIRECRAWL_API_KEY}" ]] && echo "FIRECRAWL_API_KEY=${HERMES_FIRECRAWL_API_KEY}"
        [[ -n "${HERMES_FAL_KEY}" ]] && echo "FAL_KEY=${HERMES_FAL_KEY}"
        [[ -n "${HERMES_VOICE_OPENAI_KEY}" ]] && echo "VOICE_TOOLS_OPENAI_KEY=${HERMES_VOICE_OPENAI_KEY}"
        [[ -n "${HERMES_ELEVENLABS_KEY}" ]] && echo "ELEVENLABS_API_KEY=${HERMES_ELEVENLABS_KEY}"
        echo ""
        
        # Terminal Backend
        [[ -n "${HERMES_TERMINAL_BACKEND}" ]] && echo "TERMINAL_ENV=${HERMES_TERMINAL_BACKEND}"
        [[ -n "${HERMES_TERMINAL_TIMEOUT}" ]] && echo "TERMINAL_TIMEOUT=${HERMES_TERMINAL_TIMEOUT}"
        [[ -n "${HERMES_TERMINAL_CWD}" ]] && echo "TERMINAL_CWD=${HERMES_TERMINAL_CWD}"
        
    } > "${ENV_FILE}"
    
    log_success "Environment file written: ${ENV_FILE}"
}

# =============================================================================
# Create Default Configuration
# =============================================================================

create_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        log_info "Configuration file already exists: ${CONFIG_FILE}"
        return 0
    fi
    
    log_info "Creating default configuration..."
    
    cat > "${CONFIG_FILE}" <<EOF
# Hermes Agent Configuration
# Railway Template - Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

terminal:
  backend: ${HERMES_TERMINAL_BACKEND:-docker}
  cwd: ${MESSAGING_CWD}
  timeout: ${HERMES_TERMINAL_TIMEOUT:-180}

compression:
  enabled: true
  threshold: 0.85

models:
  default: ${HERMES_MODEL:-anthropic/claude-opus-4.6}

stt:
  provider: local

gateway:
  auto_start: true
EOF
    
    log_success "Configuration file created: ${CONFIG_FILE}"
}

# =============================================================================
# Initialize Hermes (First Boot)
# =============================================================================

initialize_hermes() {
    if [[ -f "${INIT_MARKER}" ]]; then
        log_info "Hermes already initialized (marker found)"
        return 0
    fi
    
    log_info "First-time initialization..."
    
    # Create SOUL.md if missing
    if [[ ! -f "${HERMES_HOME}/SOUL.md" ]]; then
        cat > "${HERMES_HOME}/SOUL.md" <<'EOF'
# Hermes Agent Persona

<!--
This file defines the agent's personality and tone.
The agent will embody whatever you write here.
Edit this to customize how Hermes communicates with you.

Examples:
  - "You are a warm, playful assistant who uses kaomoji occasionally."
  - "You are a concise technical expert. No fluff, just facts."
  - "You speak like a friendly coworker who happens to know everything."

This file is loaded fresh each message -- no restart needed.
Delete the contents (or this file) to use the default personality.
-->
EOF
        log_success "Created SOUL.md"
    fi
    
    # Sync bundled skills
    if [[ -d "/opt/hermes-agent/skills" ]]; then
        log_info "Syncing bundled skills..."
        if command -v python3 &> /dev/null; then
            python3 /opt/hermes-agent/tools/skills_sync.py 2>/dev/null || {
                # Fallback: simple copy
                cp -r /opt/hermes-agent/skills/* "${HERMES_HOME}/skills/" 2>/dev/null || true
            }
        else
            cp -r /opt/hermes-agent/skills/* "${HERMES_HOME}/skills/" 2>/dev/null || true
        fi
        log_success "Skills synced"
    fi
    
    # Create initialization marker
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "${INIT_MARKER}"
    log_success "Initialization complete"
}

# =============================================================================
# Start Docker Daemon
# =============================================================================

start_docker() {
    log_info "Starting Docker daemon..."
    
    # Check if we can run Docker
    if [[ ! -S /var/run/docker.sock ]]; then
        # Start Docker daemon in background
        dockerd --host=unix:///var/run/docker.sock \
                --host=tcp://127.0.0.1:2375 \
                --storage-driver=vfs \
                --iptables=false \
                > /var/log/docker.log 2>&1 &
        
        # Wait for Docker to be ready
        local retries=30
        while [[ $retries -gt 0 ]]; do
            if docker info &> /dev/null; then
                log_success "Docker daemon started"
                return 0
            fi
            sleep 1
            ((retries--))
        done
        
        log_warn "Docker daemon failed to start, falling back to local backend"
        export HERMES_TERMINAL_BACKEND="local"
        # Update config file to use local backend
        sed -i 's/backend: docker/backend: local/' "${CONFIG_FILE}"
    else
        log_success "Docker socket already available"
    fi
}

# =============================================================================
# Auto-Start Gateway
# =============================================================================

auto_start_gateway() {
    local auto_start="${HERMES_AUTO_START_GATEWAY:-true}"
    
    if [[ "${auto_start}" != "true" ]]; then
        log_info "Auto-start disabled (HERMES_AUTO_START_GATEWAY != true)"
        return 0
    fi
    
    log_info "Auto-starting Hermes gateway in background..."
    
    # Start gateway in background and redirect logs
    nohup hermes gateway > "${HERMES_HOME}/logs/gateway.log" 2>&1 &
    
    log_success "Gateway started (PID: $!)"
    log_info "Logs available at: ${HERMES_HOME}/logs/gateway.log"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          ⚕ Hermes Agent Railway Template                ║"
    echo "║                    Version: ${HERMES_VERSION}                        ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    # Setup
    setup_directories
    generate_password
    validate_environment
    write_env_file
    create_config
    initialize_hermes
    
    # Start Docker (with fallback)
    start_docker || true
    
    # Display startup info
    echo ""
    echo "================================================"
    echo "  Dashboard URL: http://localhost:${PORT}"
    echo "  Health Check:  http://localhost:${PORT}/health"
    echo "================================================"
    echo ""
    
    # Auto-start gateway if configured
    auto_start_gateway
    
    # Start web server
    log_info "Starting web server..."
    exec python3 /app/server.py
}

# Run main function
main "$@"
