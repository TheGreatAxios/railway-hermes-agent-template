#!/bin/sh
# =============================================================================
# Hermes Agent Railway Template - Entrypoint
#
# Wraps the official image entrypoint (/opt/hermes/docker/entrypoint-dispatch.sh)
# to prime Railway-specific environment, then hands off unchanged so the
# s6-overlay supervision tree (gateway + dashboard) works as upstream intends.
# =============================================================================

set -eu

# -----------------------------------------------------------------------------
# Dashboard port: Railway injects PORT for the public domain.
# -----------------------------------------------------------------------------
HERMES_DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-${PORT:-9119}}"
export HERMES_DASHBOARD_PORT

# Public origin: Host/WebSocket Origin guard and OAuth callbacks behind Railway TLS.
if [ -z "${HERMES_DASHBOARD_PUBLIC_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    HERMES_DASHBOARD_PUBLIC_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
    export HERMES_DASHBOARD_PUBLIC_URL
fi

# -----------------------------------------------------------------------------
# Dashboard auth: mandatory on non-loopback binds (upstream fails closed
# without an auth provider, by design — June 2026 hardening).
# -----------------------------------------------------------------------------
HERMES_DASHBOARD_BASIC_AUTH_USERNAME="${HERMES_DASHBOARD_BASIC_AUTH_USERNAME:-${ADMIN_USERNAME:-admin}}"
export HERMES_DASHBOARD_BASIC_AUTH_USERNAME

if [ -z "${HERMES_DASHBOARD_BASIC_AUTH_PASSWORD:-}" ]; then
    PASSWORD_FILE="/opt/data/.dashboard_password"
    if [ -f "${PASSWORD_FILE}" ]; then
        HERMES_DASHBOARD_BASIC_AUTH_PASSWORD="$(cat "${PASSWORD_FILE}")"
    else
        HERMES_DASHBOARD_BASIC_AUTH_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(18))')"
        mkdir -p /opt/data
        printf '%s' "${HERMES_DASHBOARD_BASIC_AUTH_PASSWORD}" > "${PASSWORD_FILE}"
        chmod 600 "${PASSWORD_FILE}"
        echo ""
        echo "================================================================"
        echo "  Dashboard Username: ${HERMES_DASHBOARD_BASIC_AUTH_USERNAME}"
        echo "  Dashboard Password: ${HERMES_DASHBOARD_BASIC_AUTH_PASSWORD}"
        echo "================================================================"
        echo ""
        echo "Auto-generated because HERMES_DASHBOARD_BASIC_AUTH_PASSWORD was not set."
        echo "Set that variable to control the password (visible only in this log)."
    fi
fi
export HERMES_DASHBOARD_BASIC_AUTH_PASSWORD

# -----------------------------------------------------------------------------
# Dashboard session secret: persist one in the data volume so dashboard
# logins survive container restarts.
# -----------------------------------------------------------------------------
if [ -z "${HERMES_DASHBOARD_BASIC_AUTH_SECRET:-}" ]; then
    SECRET_FILE="/opt/data/.dashboard_secret"
    if [ -f "${SECRET_FILE}" ]; then
        HERMES_DASHBOARD_BASIC_AUTH_SECRET="$(cat "${SECRET_FILE}")"
    else
        HERMES_DASHBOARD_BASIC_AUTH_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
        mkdir -p /opt/data
        printf '%s' "${HERMES_DASHBOARD_BASIC_AUTH_SECRET}" > "${SECRET_FILE}"
        chmod 600 "${SECRET_FILE}"
    fi
    export HERMES_DASHBOARD_BASIC_AUTH_SECRET
fi

# -----------------------------------------------------------------------------
# First-boot hints (non-fatal: everything below can be configured later
# from the dashboard's API Keys / Channels pages).
# -----------------------------------------------------------------------------
if [ -z "${OPENROUTER_API_KEY:-}${ANTHROPIC_API_KEY:-}${OPENAI_API_KEY:-}${GLM_API_KEY:-}${KIMI_API_KEY:-}${MINIMAX_API_KEY:-}${DEEPSEEK_API_KEY:-}" ]; then
    echo "[hermes-railway] No LLM provider key detected (e.g. OPENROUTER_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY)."
    echo "[hermes-railway] The agent will not be able to respond until you add one"
    echo "[hermes-railway] via Railway variables or the dashboard's API Keys page."
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}${DISCORD_BOT_TOKEN:-}${SLACK_BOT_TOKEN:-}${SLACK_APP_TOKEN:-}" ] && [ "${WHATSAPP_ENABLED:-}" != "true" ]; then
    echo "[hermes-railway] No messaging platform token detected (TELEGRAM_BOT_TOKEN, DISCORD_BOT_TOKEN, SLACK_BOT_TOKEN, ...)."
    echo "[hermes-railway] Configure a channel from the dashboard's Channels page when ready."
fi

# -----------------------------------------------------------------------------
# Hand off to the official entrypoint (s6-overlay supervised gateway + dashboard)
# -----------------------------------------------------------------------------
exec /opt/hermes/docker/entrypoint-dispatch.sh "$@"
