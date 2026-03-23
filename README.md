# Hermes Agent Railway Template

One-click deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) on [Railway](https://railway.app) with a web-based config UI, status dashboard, and full messaging platform support.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/template/YOUR_TEMPLATE_ID)

## What You Get

- **Web Config UI** — Configure providers, platforms, and agent settings from your browser
- **Status Dashboard** — Monitor gateway state, platform connections, and live logs
- **Gateway Management** — Start, stop, and restart the Hermes gateway from the UI
- **Docker Terminal Backend** — Run commands in isolated Docker containers (with local fallback)
- **Multi-Platform Support** — Telegram, Discord, Slack, and WhatsApp from one deployment
- **Persistent Storage** — Config, skills, memory, and data survive container restarts (10GB recommended)
- **Basic Auth** — Password-protected admin panel
- **Auto-Initialization** — First-boot setup with environment variable seeding

## Quick Start

### 1. Deploy to Railway

Click the "Deploy on Railway" button above.

### 2. Configure Environment Variables

During deployment, set at least:

**Required: LLM Provider** (choose one)
- `HERMES_OPENROUTER_API_KEY` — Recommended (access to 200+ models)
- `HERMES_ANTHROPIC_API_KEY` — Claude models
- `HERMES_OPENAI_API_KEY` — GPT models
- `HERMES_GLM_API_KEY` — Zhipu GLM (z.ai)
- `HERMES_KIMI_API_KEY` — Moonshot/Kimi coding models

**Required: Messaging Platform** (choose at least one)
- `HERMES_TELEGRAM_TOKEN` + `HERMES_TELEGRAM_ALLOWED_USERS`
- `HERMES_DISCORD_TOKEN` + `HERMES_DISCORD_ALLOWED_USERS`
- `HERMES_SLACK_BOT_TOKEN` + `HERMES_SLACK_APP_TOKEN` + `HERMES_SLACK_ALLOWED_USERS`

**Security**
- `ADMIN_PASSWORD` — Web UI password (auto-generated if not set)

### 3. Attach Volume

In Railway, attach a volume mounted at `/data` (recommend 10GB).

### 4. Access Dashboard

Once deployed:
1. Open your Railway service URL
2. Log in with `admin` / your `ADMIN_PASSWORD`
3. View the dashboard — gateway auto-starts if configured
4. Test your bot on the configured platform(s)

### 5. Secure Your Deployment

Once confirmed working, remove the public endpoint from your Railway service and access only via Railway's internal networking or VPN.

## Architecture

```
Railway Container
├── Web Server (Starlette + Uvicorn)
│   ├── / — Dashboard with config editor, status, logs
│   ├── /health — Health check endpoint
│   └── /api/* — REST API for management
├── Hermes Gateway (subprocess)
│   └── Handles Telegram/Discord/Slack/WhatsApp
└── Docker Engine (optional)
    └── User commands run in isolated containers

Persistent Volume: /data (10GB recommended)
├── /data/.hermes/ — Hermes config, skills, memory
└── /data/workspace/ — Working directory for terminal
```

## Environment Variables

### Web UI

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Web server port |
| `ADMIN_USERNAME` | `admin` | Basic auth username |
| `ADMIN_PASSWORD` | *(random)* | Basic auth password (printed to logs if not set) |

### LLM Providers (at least one required)

| Variable | Description |
|----------|-------------|
| `HERMES_OPENROUTER_API_KEY` | [OpenRouter](https://openrouter.ai/keys) — Recommended (200+ models) |
| `HERMES_ANTHROPIC_API_KEY` | [Anthropic](https://console.anthropic.com/) — Claude models |
| `HERMES_OPENAI_API_KEY` | [OpenAI](https://platform.openai.com/api-keys) — GPT models |
| `HERMES_GLM_API_KEY` | [Zhipu AI](https://z.ai) / [Open BigModel](https://open.bigmodel.cn) — GLM-4/GLM-5 |
| `HERMES_KIMI_API_KEY` | [Kimi Code](https://platform.kimi.ai) / [Moonshot](https://platform.moonshot.cn) — Kimi K2.5 |
| `HERMES_MINIMAX_API_KEY` | [MiniMax](https://www.minimax.io) — MiniMax models |
| `HERMES_NOUS_PORTAL_KEY` | [Nous Portal](https://portal.nousresearch.com) — Hermes-optimized models |

**Provider Selection:**
- Set `HERMES_PROVIDER` to force a specific provider (e.g., `openrouter`, `anthropic`, `glm`)
- If multiple keys are set, auto-selection picks based on model preference

### Agent Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `HERMES_MODEL` | `anthropic/claude-opus-4.6` | Default LLM model |
| `HERMES_MAX_TOKENS` | `8192` | Max tokens per response |
| `HERMES_TEMPERATURE` | `0.7` | Sampling temperature (0-2) |
| `HERMES_MAX_ITERATIONS` | `50` | Max tool iterations per request |

### Messaging Platforms (at least one required)

#### Telegram

| Variable | Description |
|----------|-------------|
| `HERMES_TELEGRAM_TOKEN` | Bot token from [@BotFather](https://t.me/botfather) |
| `HERMES_TELEGRAM_ALLOWED_USERS` | Comma-separated Telegram user IDs |
| `HERMES_TELEGRAM_HOME_CHANNEL` | Channel/group ID for bot responses |

Get your Telegram user ID: [@userinfobot](https://t.me/userinfobot)

#### Discord

| Variable | Description |
|----------|-------------|
| `HERMES_DISCORD_TOKEN` | Bot token from [Discord Developer Portal](https://discord.com/developers/applications) |
| `HERMES_DISCORD_ALLOWED_USERS` | Comma-separated Discord user IDs |
| `HERMES_DISCORD_HOME_CHANNEL` | Channel ID for bot responses |

Enable "Message Content Intent" in your Discord bot settings.

#### Slack

| Variable | Description |
|----------|-------------|
| `HERMES_SLACK_BOT_TOKEN` | Bot token (`xoxb-...`) from OAuth & Permissions |
| `HERMES_SLACK_APP_TOKEN` | App-level token (`xapp-...`) for Socket Mode |
| `HERMES_SLACK_ALLOWED_USERS` | Comma-separated Slack user IDs (e.g., `U01234ABCDE`) |
| `HERMES_SLACK_HOME_CHANNEL` | Channel ID for bot responses |

Enable Socket Mode in your Slack app settings.

#### WhatsApp

| Variable | Description |
|----------|-------------|
| `HERMES_WHATSAPP_ENABLED` | Set to `true` to enable |
| `HERMES_WHATSAPP_ALLOWED_USERS` | Comma-separated phone numbers (e.g., `15551234567`) |

**Note:** First-time WhatsApp setup requires pairing via QR code. SSH into the container and run `hermes whatsapp` to pair.

### Tool API Keys (Optional)

| Variable | Description |
|----------|-------------|
| `HERMES_BROWSERBASE_API_KEY` | [Browserbase](https://browserbase.com) for web automation |
| `HERMES_BROWSERBASE_PROJECT_ID` | Browserbase project ID |
| `HERMES_PARALLEL_API_KEY` | [Parallel](https://parallel.ai) for AI-native web search |
| `HERMES_FIRECRAWL_API_KEY` | [Firecrawl](https://firecrawl.dev) for web extraction |
| `HERMES_FAL_KEY` | [FAL.ai](https://fal.ai) for image generation |
| `HERMES_VOICE_OPENAI_KEY` | [OpenAI](https://platform.openai.com/api-keys) for voice/TTS |
| `HERMES_ELEVENLABS_KEY` | [ElevenLabs](https://elevenlabs.io) for premium TTS |

### Terminal Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `HERMES_TERMINAL_BACKEND` | `docker` | Backend: `docker`, `local`, `ssh`, `modal` |
| `HERMES_TERMINAL_TIMEOUT` | `180` | Command timeout in seconds |
| `HERMES_TERMINAL_CWD` | `/data/workspace` | Working directory |

**Backends:**
- `docker` — Run commands in isolated containers (recommended, requires volume)
- `local` — Run directly in container (fallback if Docker unavailable)
- `modal` — Serverless containers via [Modal](https://modal.com)
- `ssh` — Run on remote server

### Security

| Variable | Default | Description |
|----------|---------|-------------|
| `HERMES_GATEWAY_ALLOW_ALL` | `false` | Allow all users (⚠️ not recommended) |
| `HERMES_TELEGRAM_ALLOW_ALL` | `false` | Allow all Telegram users |
| `HERMES_DISCORD_ALLOW_ALL` | `false` | Allow all Discord users |
| `HERMES_SLACK_ALLOW_ALL` | `false` | Allow all Slack users |

**Strongly recommended:** Always use `*_ALLOWED_USERS` instead of allowing all users.

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/` | Yes | Main dashboard |
| `GET` | `/health` | No | Health check |
| `GET` | `/api/config` | Yes | Get Hermes configuration |
| `PUT` | `/api/config` | Yes | Update Hermes configuration |
| `GET` | `/api/status` | Yes | Gateway status, platform connections |
| `GET` | `/api/logs` | Yes | Recent gateway logs (last 100 lines) |
| `POST` | `/api/gateway/start` | Yes | Start Hermes gateway |
| `POST` | `/api/gateway/stop` | Yes | Stop Hermes gateway |
| `POST` | `/api/gateway/restart` | Yes | Restart Hermes gateway |

## Local Development

### Build and run locally:

```bash
docker build -t hermes-railway .
docker run --rm -it \
  -p 8080:8080 \
  -e PORT=8080 \
  -e ADMIN_PASSWORD=changeme \
  -e HERMES_OPENROUTER_API_KEY=sk-or-xxx \
  -e HERMES_TELEGRAM_TOKEN=123456:ABC \
  -e HERMES_TELEGRAM_ALLOWED_USERS=123456789 \
  -v $(pwd)/.tmpdata:/data \
  hermes-railway
```

Access at `http://localhost:8080`

### SSH into Railway container:

```bash
railway ssh
# Then run Hermes CLI commands:
hermes status
hermes config
hermes pairing list
hermes whatsapp  # For WhatsApp QR pairing
```

## Supported Models

Hermes Agent works with any OpenAI-compatible API:

- **Claude** (via Anthropic or OpenRouter)
- **GPT-4/GPT-3.5** (OpenAI)
- **GLM-4/GLM-5** (Zhipu AI / z.ai)
- **Kimi K2.5** (Moonshot)
- **MiniMax** (MiniMax)
- **200+ models** (via OpenRouter)
- **Self-hosted** (vLLM, Ollama, etc.)

## Troubleshooting

### Gateway won't start

1. Check Railway logs for errors
2. Verify at least one LLM provider key is set
3. Verify at least one messaging platform token is set
4. Check `HERMES_*_ALLOWED_USERS` is set correctly

### No replies from bot

1. Confirm platform token is valid
2. Check user ID is in allowlist
3. Verify bot has necessary permissions (Discord intents, etc.)
4. Check gateway logs in dashboard

### Terminal commands fail

1. Docker backend: Ensure volume is mounted at `/data`
2. Switch to local backend: Set `HERMES_TERMINAL_BACKEND=local`
3. Check `HERMES_TERMINAL_TIMEOUT` isn't too low

### Data lost after restart

1. Ensure Railway volume is mounted at `/data`
2. Check volume has read/write permissions
3. Volume should be at least 10GB for long-term use

### 401 Unauthorized errors

1. Check API key is valid and has credits
2. Verify `HERMES_PROVIDER` matches the key provider
3. Some providers require base URL override

## Version Information

- **Hermes Agent**: `v2026.3.17` (pinned)
- **Python**: 3.11
- **Node.js**: 22 LTS
- **Docker**: CE (for terminal backend)

## Updating

To update to a newer Hermes version:

1. Fork this repository
2. Update `HERMES_VERSION` in `Dockerfile`
3. Rebuild and redeploy

Or use Railway's "Deploy from GitHub" to auto-deploy on push.

## Resources

- [Hermes Agent Documentation](https://hermes-agent.nousresearch.com/docs/)
- [Hermes GitHub](https://github.com/NousResearch/hermes-agent)
- [Railway Documentation](https://docs.railway.com/)
- [OpenRouter Models](https://openrouter.ai/models)

## License

MIT — see [LICENSE](./LICENSE)

Built by [Nous Research](https://nousresearch.com) · Template by [TheGreatAxios](https://github.com/thegreataxios)
