# Hermes Agent Railway Template - Implementation Plan

## Project Overview

A 1-click deploy Railway template for [Hermes Agent](https://github.com/NousResearch/hermes-agent) with:
- Full web-based configuration UI (like nanobot template)
- Status dashboard with live logs
- Gateway control (start/stop/restart)
- Support for Telegram, Discord, Slack, WhatsApp
- Persistent storage via Railway volume
- Docker-in-Docker support for terminal backend

## Architecture

```
Railway Container
├── Web Server (Python + Starlette)
│   ├── / — Config editor + status dashboard (Basic Auth)
│   ├── /health — Health check (no auth)
│   └── /api/* — REST endpoints for management
├── Hermes Gateway (subprocess)
│   └── Handles Telegram/Discord/Slack/WhatsApp
└── Docker Engine (for terminal backend)
    └── User commands run in isolated containers

Persistent Volume: /data
├── /data/.hermes/ — Hermes config, skills, memory
└── /data/workspace/ — Working directory for terminal
```

## File Structure

```
hermes-railway-template/
├── Dockerfile                    # Multi-stage: Python + Hermes + Docker
├── railway.toml                 # Railway service configuration
├── README.md                    # Deploy instructions, env vars reference
├── .env.example                 # Documentation for all env vars
├── .gitignore                   # Standard Python gitignore
├── requirements.txt             # Web server dependencies
├── server.py                    # Starlette web server with API
├── start.sh                     # Container entrypoint
└── templates/
    ├── index.html               # Dashboard UI
    ├── login.html               # Auth page
    └── static/
        ├── style.css            # Dashboard styles
        └── app.js               # Frontend JavaScript
```

## Technical Specifications

### Pinning Strategy

- **Hermes Version**: `v2026.3.17` (latest release tag)
- **Python**: 3.11
- **Node.js**: 22 LTS
- **Base Image**: `python:3.11-slim-bookworm`

### Dependencies

**Web Server:**
```
starlette
uvicorn[standard]
python-multipart
aiofiles
pyyaml
```

**Hermes (installed via Git clone + uv):**
- Cloned from `https://github.com/NousResearch/hermes-agent.git`
- Pinned to tag `v2026.3.17`
- Installed with `[all,messaging,cron]` extras

### Environment Variables

#### Web UI Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Web server port |
| `ADMIN_USERNAME` | `admin` | Basic auth username |
| `ADMIN_PASSWORD` | *(generated)* | Basic auth password |

#### LLM Provider Keys (at least one required)
| Variable | Description |
|----------|-------------|
| `HERMES_OPENROUTER_API_KEY` | OpenRouter API key (recommended) |
| `HERMES_OPENAI_API_KEY` | OpenAI API key |
| `HERMES_ANTHROPIC_API_KEY` | Anthropic API key |
| `HERMES_GLM_API_KEY` | Zhipu GLM API key |
| `HERMES_KIMI_API_KEY` | Moonshot/Kimi API key |
| `HERMES_MINIMAX_API_KEY` | MiniMax API key |

#### Messaging Platforms (at least one required)
| Variable | Description |
|----------|-------------|
| `HERMES_TELEGRAM_TOKEN` | Telegram bot token from @BotFather |
| `HERMES_TELEGRAM_ALLOWED_USERS` | Comma-separated Telegram user IDs |
| `HERMES_DISCORD_TOKEN` | Discord bot token |
| `HERMES_DISCORD_ALLOWED_USERS` | Comma-separated Discord user IDs |
| `HERMES_SLACK_BOT_TOKEN` | Slack bot token (xoxb-...) |
| `HERMES_SLACK_APP_TOKEN` | Slack app token (xapp-...) |
| `HERMES_SLACK_ALLOWED_USERS` | Comma-separated Slack user IDs |
| `HERMES_WHATSAPP_ENABLED` | Enable WhatsApp bridge (true/false) |
| `HERMES_WHATSAPP_ALLOWED_USERS` | Comma-separated phone numbers |

#### Agent Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `HERMES_MODEL` | `anthropic/claude-opus-4.6` | Default LLM model |
| `HERMES_PROVIDER` | *(auto)* | Force specific provider |
| `HERMES_MAX_TOKENS` | `8192` | Max tokens per response |
| `HERMES_TEMPERATURE` | `0.7` | Sampling temperature |
| `HERMES_MAX_ITERATIONS` | `50` | Max tool iterations |

#### Terminal Backend
| Variable | Default | Description |
|----------|---------|-------------|
| `HERMES_TERMINAL_BACKEND` | `docker` | Terminal backend type |
| `HERMES_TERMINAL_TIMEOUT` | `180` | Command timeout (seconds) |

#### Tool API Keys (optional)
| Variable | Description |
|----------|-------------|
| `HERMES_BROWSERBASE_API_KEY` | Browserbase for web automation |
| `HERMES_BROWSERBASE_PROJECT_ID` | Browserbase project ID |
| `HERMES_PARALLEL_API_KEY` | Parallel AI web search |
| `HERMES_FIRECRAWL_API_KEY` | Firecrawl web extraction |
| `HERMES_FAL_KEY` | FAL.ai image generation |
| `HERMES_VOICE_OPENAI_KEY` | OpenAI for voice/TTS |

#### Security
| Variable | Default | Description |
|----------|---------|-------------|
| `HERMES_GATEWAY_ALLOW_ALL` | `false` | Allow all users (not recommended) |

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | Yes | Main dashboard |
| GET | `/health` | No | Health check for Railway |
| GET | `/api/config` | Yes | Get Hermes configuration |
| PUT | `/api/config` | Yes | Update Hermes configuration |
| GET | `/api/status` | Yes | Gateway status, platform connections |
| GET | `/api/logs` | Yes | Recent gateway logs (tail -n 100) |
| POST | `/api/gateway/start` | Yes | Start Hermes gateway |
| POST | `/api/gateway/stop` | Yes | Stop Hermes gateway |
| POST | `/api/gateway/restart` | Yes | Restart Hermes gateway |

## Implementation Phases

### Phase 1: Core Project Files

**Files to create:**
1. `README.md` - Comprehensive documentation
2. `.gitignore` - Standard Python/Railway gitignore
3. `railway.toml` - Railway service configuration
4. `.env.example` - Environment variable documentation

### Phase 2: Dockerfile

**Multi-stage build:**
1. **Stage 1: Builder**
   - Install uv package manager
   - Clone Hermes repo (pinned to v2026.3.17)
   - Initialize mini-swe-agent submodule
   - Install Python dependencies with uv
   - Install Node.js 22
   - Install Playwright browsers

2. **Stage 2: Runtime**
   - Install Docker CE (for terminal backend)
   - Copy Hermes installation from builder
   - Set up entrypoint
   - Expose port 8080

**Key features:**
- Docker-in-Docker support (container runs Docker daemon)
- All Hermes dependencies pre-installed
- Pinned versions for reproducibility

### Phase 3: Web Server (server.py)

**Starlette application with:**
- Basic HTTP auth middleware
- Static file serving
- API routes for config/status/logs
- Subprocess management for gateway
- YAML config file editing
- Log tailing with streaming

**Key classes/functions:**
- `HermesManager` - Manages gateway subprocess
- `ConfigManager` - Reads/writes config.yaml
- `AuthMiddleware` - Basic HTTP auth
- Route handlers for API endpoints

### Phase 4: HTML Templates

**index.html features:**
- Tabbed interface: Dashboard | Config | Logs | Status
- Config editor with YAML syntax highlighting
- Real-time log viewer with auto-refresh
- Gateway control buttons (start/stop/restart)
- Platform status indicators (Telegram/Discord/Slack connection state)
- Mobile-responsive design

**login.html:**
- Simple auth form
- Styled to match dashboard

### Phase 5: Entrypoint Script (start.sh)

**Responsibilities:**
1. Initialize volume directories
2. Generate random admin password if not set
3. Validate required environment variables
4. Write Hermes .env file from Railway vars
5. Create initial config.yaml if missing
6. Initialize Hermes skills and SOUL.md
7. Start web server
8. Optionally auto-start gateway if configured

**First-boot initialization:**
- Copy bundled skills
- Create default SOUL.md
- Set up workspace directory

### Phase 6: Testing & Verification

**Local testing:**
```bash
docker build -t hermes-railway .
docker run --rm -it \
  -p 8080:8080 \
  -e HERMES_OPENROUTER_API_KEY=test \
  -e HERMES_TELEGRAM_TOKEN=test \
  -e ADMIN_PASSWORD=test \
  -v /tmp/hermes-data:/data \
  hermes-railway
```

**Railway deploy button URL:**
```
https://railway.com/deploy?template=https://github.com/thegreataxios/hermes-railway-template&referralCode=YOUR_CODE
```

## Docker-in-Docker Implementation

**Challenge:** Hermes terminal backend needs to run commands in Docker containers, but Railway containers don't have Docker by default.

**Solution:**
1. Install Docker CE in the container
2. Run Docker daemon as rootless or with proper permissions
3. Use privileged mode or docker-in-docker approach

**Implementation:**
```dockerfile
# Install Docker
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io

# Start Docker daemon in background
RUN mkdir -p /var/run/docker
```

## Configuration Management

**Hermes Config File (~/.hermes/config.yaml):**
```yaml
terminal:
  backend: docker
  cwd: /data/workspace
  timeout: 180
compression:
  enabled: true
  threshold: 0.85
models:
  default: anthropic/claude-opus-4.6
```

**Web UI Config Editor:**
- Edit YAML directly with syntax validation
- Toggle sections (terminal, compression, models)
- Save/reset buttons
- Success/error notifications

## Gateway Management

**HermesManager class:**
- Manages subprocess lifecycle
- Captures stdout/stderr to log buffer
- Implements start/stop/restart
- Health check via process status

**Log Streaming:**
- Circular buffer (last 1000 lines)
- API endpoint returns JSON array
- Frontend polls every 2 seconds
- Auto-scroll to bottom

## Security Considerations

1. **Basic Auth**: All endpoints except /health require authentication
2. **Env Var Masking**: Secrets never exposed in API responses
3. **Volume Permissions**: Proper ownership for /data directories
4. **Allowlists**: Strongly recommended for all platforms
5. **No Gateway Allow All**: Defaults to false, explicit opt-in required

## Deployment Checklist

- [ ] All files created
- [ ] Dockerfile builds successfully
- [ ] Local Docker test passes
- [ ] Railway template button works
- [ ] Volume mount at /data persists data
- [ ] Web UI accessible and functional
- [ ] Gateway starts and connects to platforms
- [ ] Terminal backend works (Docker-in-Docker)
- [ ] Logs visible in dashboard
- [ ] Config editable via web UI
- [ ] Documentation complete

## Post-Deploy User Flow

1. Click "Deploy on Railway" button
2. Add volume mounted at `/data`
3. Configure environment variables:
   - Add LLM provider key
   - Add messaging platform token(s)
   - Add allowed user IDs
4. Deploy service
5. Access web UI at Railway URL
6. Log in with admin credentials
7. View dashboard - shows gateway status
8. Start gateway if not auto-started
9. Test bot on configured platform(s)
10. (Optional) Remove public endpoint once configured

## Future Enhancements

- WebSocket for real-time log streaming
- Hermes CLI via browser terminal (ttyd/xterm.js)
- Multi-user support with different permission levels
- Backup/restore configuration
- Metrics dashboard (prometheus/grafana)
- Integration with Railway's native health checks

## References

- Hermes Agent: https://github.com/NousResearch/hermes-agent
- Hermes Docs: https://hermes-agent.nousresearch.com/docs/
- nanobot Template: https://github.com/thegreataxios/nanobot-railway-template
- lovexbytes Template: https://github.com/lovexbytes/hermes-railway-template
- Railway Docs: https://docs.railway.com/
