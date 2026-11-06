# Deploy and Host Hermes Agent on Railway

One-click deploy of [Hermes Agent](https://github.com/NousResearch/hermes-agent) on [Railway](https://railway.app), using the official `nousresearch/hermes-agent` Docker image with the built-in web dashboard enabled.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/hermes-agent-8)

## About Hosting

Hosting Hermes Agent means running a persistent gateway process that connects your messaging platforms (Telegram, Discord, Slack, WhatsApp) to an LLM-powered agent, alongside a web dashboard for configuration and monitoring. The service runs as a single Railway container: the gateway and dashboard are supervised in-process, and all agent state (config, API keys, skills, memories, sessions) lives on a persistent volume mounted at `/opt/data`. Plan for at least 2 GB of RAM (4 GB recommended with browser tools) and ~1 GB of image storage.

## Why Deploy Hermes Agent on Railway?

- **Zero server maintenance** — no VPS to provision, patch, or back up. Railway handles the runtime, restarts the service on failure, and gives you logs and metrics out of the box.
- **Always current** — the template builds from the official `nousresearch/hermes-agent` image, so you run exactly what Nous Research ships.
- **Configurable in the browser** — add API keys, connect messaging channels, edit `config.yaml`, and chat with the agent from the built-in dashboard; no SSH required.
- **Persistent by default** — a volume mount keeps your agent's memory, skills, and sessions across restarts and upgrades.

## Common Use Cases

- A personal AI assistant in Telegram, Discord, or Slack with allowlisted users
- A persistent, self-improving agent with skills, memory, and cron-scheduled jobs
- A team's shared agent that monitors channels and responds to prompts
- An OpenAI-compatible agent API (optional gateway API server) for your own apps

## Dependencies for Hermes Agent

- **An LLM provider API key** (at least one): OpenRouter (recommended), Anthropic, OpenAI, GLM, Kimi, MiniMax, DeepSeek, and more
- **A messaging platform token** (at least one to chat with the agent): Telegram, Discord, Slack, or WhatsApp
- **A Railway volume** mounted at `/opt/data` for persistent state (the template creates this for you)

### Deployment Dependencies

- [nousresearch/hermes-agent](https://hub.docker.com/r/nousresearch/hermes-agent) — the official Hermes Agent Docker image (pinned release tag)
- Railway volume — persistent storage for agent state
- Railway HTTP domain — serves the dashboard with automatic TLS

## What You Get

- **Official image** — the template runs `nousresearch/hermes-agent` (pinned tag), so the gateway, dashboard, and CLI are exactly what Nous Research ships. No source builds.
- **Built-in web dashboard** — configure API keys and channels, edit `config.yaml`, browse sessions and logs, manage cron jobs, and chat with the agent in the browser.
- **Supervised gateway** — Telegram, Discord, Slack, WhatsApp and more, auto-restarted by s6-overlay if it crashes.
- **Persistent storage** — all agent state (config, keys, skills, memory, sessions) on a Railway volume.
- **Secure by default** — dashboard authentication is enforced on public URLs; it fails closed without credentials.

## Quick Start

### 1. Deploy to Railway

Click the deploy button above (or in Railway: **New Project → Deploy from GitHub repo**, selecting this repository).

### 2. Configure environment variables

In your Railway service, set:

**Dashboard login (recommended)**
- `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` — if unset, a strong password is auto-generated and printed once in the deploy logs.

**LLM provider (at least one)**
- `OPENROUTER_API_KEY` — recommended (200+ models)
- `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / `GLM_API_KEY` / `KIMI_API_KEY` / `MINIMAX_API_KEY` / `DEEPSEEK_API_KEY`

**Messaging platform (at least one)**
- `TELEGRAM_BOT_TOKEN` + `TELEGRAM_ALLOWED_USERS` (get a token from [@BotFather](https://t.me/botfather), your user ID from [@userinfobot](https://t.me/userinfobot))
- `DISCORD_BOT_TOKEN` + `DISCORD_ALLOWED_USERS` (enable "Message Content Intent")
- `SLACK_BOT_TOKEN` + `SLACK_APP_TOKEN` + `SLACK_ALLOWED_USERS` (Socket Mode)
- `WHATSAPP_ENABLED=true`

You can skip the provider/platform variables and add everything later from the dashboard's **API Keys** and **Channels** pages — the container starts either way and tells you what's missing in the logs.

### 3. Attach a volume

Attach a Railway volume mounted at **`/opt/data`** (this is Hermes' home: `.env`, `config.yaml`, `sessions/`, `memories/`, `skills/`). 10 GB is plenty.

### 4. Open the dashboard

1. Open your Railway service URL.
2. Log in with the dashboard credentials (from your variable, or the generated password in the deploy logs).
3. The gateway starts automatically as a supervised service. Configure channels or grab logs from the same UI.

### Resource sizing

The image is ~1 GB and runs the gateway plus dashboard. Give the service **at least 2 GB of RAM** (4 GB recommended if you'll use browser tools).

## Architecture

```
Railway service (official nousresearch/hermes-agent image)
├── s6-overlay (PID 1 supervision)
│   ├── hermes gateway  — Telegram / Discord / Slack / WhatsApp adapters
│   └── web dashboard   — config, API keys, sessions, logs, cron, chat
└── Volume at /opt/data — .env, config.yaml, SOUL.md, sessions, memories, skills

Template additions (this repo):
├── Dockerfile      — FROM nousresearch/hermes-agent:<pinned tag>, enables dashboard
├── start.sh        — Railway env priming (PORT, dashboard auth), then hands off
└── railway.toml    — health check on /api/status
```

## Environment Variables

Hermes reads variables directly from the process environment and from `/opt/data/.env` (manageable via the dashboard's **API Keys** page). This template uses upstream's variable names unchanged — see the [official env reference](https://hermes-agent.nousresearch.com/docs/reference/environment-variables) for the full list, and [.env.example](./.env.example) for the common ones.

### Template-managed

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | *(set by Railway)* | Forwarded to `HERMES_DASHBOARD_PORT` so the dashboard listens on the public domain |
| `HERMES_DASHBOARD` | `1` | Enables the supervised dashboard service |
| `HERMES_DASHBOARD_PUBLIC_URL` | `https://$RAILWAY_PUBLIC_DOMAIN` | Public origin for Host/WebSocket Origin checks and OAuth callbacks |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | `admin` | Dashboard login username |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | *(generated)* | Dashboard login password (printed to deploy logs once if unset; persisted on the volume) |
| `HERMES_DASHBOARD_BASIC_AUTH_SECRET` | *(generated, persisted to volume)* | Session signing secret; keeps logins stable across restarts |

### Commonly used upstream variables

| Variable | Description |
|----------|-------------|
| `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GLM_API_KEY`, `KIMI_API_KEY`, `MINIMAX_API_KEY`, `DEEPSEEK_API_KEY` | LLM provider keys (at least one) |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS`, `TELEGRAM_HOME_CHANNEL` | Telegram |
| `DISCORD_BOT_TOKEN`, `DISCORD_ALLOWED_USERS`, `DISCORD_HOME_CHANNEL` | Discord |
| `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, `SLACK_ALLOWED_USERS` | Slack (Socket Mode) |
| `WHATSAPP_ENABLED`, `WHATSAPP_ALLOWED_USERS` | WhatsApp bridge |
| `API_SERVER_ENABLED`, `API_SERVER_HOST`, `API_SERVER_KEY` | Optional OpenAI-compatible API server (port 8642) |

**Security:** always set `*_ALLOWED_USERS` for any messaging platform. Do not use the `*_ALLOW_ALL_*` variables on a public deployment.

## Security Notes

- The dashboard **requires authentication on any public bind** and refuses to start unauthenticated on one — this is upstream's fail-closed policy. Set `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` (or the generated one in your logs) to log in.
- Anyone with the dashboard URL plus your credentials can run the agent, edit config, and read sessions. Keep the password strong. For production, consider locking the service to internal networking or an OAuth provider (`HERMES_DASHBOARD_OAUTH_CLIENT_ID`).
- The agent executes terminal commands **inside the container** (local terminal backend). Treat dashboard credentials as shell access to your Railway service.
- All secrets live in the volume's `.env` and Railway's encrypted variables — never commit them.

## Local Development

```bash
docker build -t hermes-railway .
docker run --rm -it \
  -p 8080:8080 \
  -e PORT=8080 \
  -e HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=changeme \
  -e OPENROUTER_API_KEY=sk-or-xxx \
  -e TELEGRAM_BOT_TOKEN=123456:ABC \
  -e TELEGRAM_ALLOWED_USERS=123456789 \
  -v $(pwd)/.tmpdata:/opt/data \
  hermes-railway
```

Open `http://localhost:8080`. CLI access inside the running container:

```bash
docker exec -it <container> hermes status
```

## Updating

The Hermes version is pinned via `ARG HERMES_VERSION` in the [Dockerfile](./Dockerfile) (`v0.23.0` as of this template's update). To upgrade:

1. Check the [latest release](https://github.com/NousResearch/hermes-agent/releases).
2. Update `HERMES_VERSION` in the Dockerfile.
3. Commit and push — Railway rebuilds and redeploys automatically when deploying from GitHub.

Agent state lives on the volume, so upgrades keep config, sessions, and memory. (Users cannot self-upgrade the running image from the dashboard on Docker installs — upstream requires an image rebuild by design.)

## Troubleshooting

- **Dashboard won't load** — check that a volume is mounted at `/opt/data` and that the deploy logs don't show the auth-gate startup error (set a password provider — this template does it automatically).
- **Gateway up but no replies** — verify the platform token, that your user ID is in `*_ALLOWED_USERS`, and provider keys exist (dashboard → API Keys).
- **First message fails** — no LLM provider configured yet; add one via Railway variables or the API Keys page.
- **Slow first deploy** — the image is ~1 GB; subsequent deploys reuse Railway's cache.

## Resources

- [Hermes Agent documentation](https://hermes-agent.nousresearch.com/docs/) — especially [Docker](https://hermes-agent.nousresearch.com/docs/user-guide/docker) and the [Web Dashboard](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard)
- [Hermes Agent GitHub](https://github.com/NousResearch/hermes-agent)
- [Railway documentation](https://docs.railway.com/)

## License

MIT — see [LICENSE](./LICENSE)

Built by [Nous Research](https://nousresearch.com) · Template by [TheGreatAxios](https://github.com/thegreataxios)
