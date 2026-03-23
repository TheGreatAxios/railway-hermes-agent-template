#!/usr/bin/env python3
"""
Hermes Agent Railway Template - Web Server
Starlette-based dashboard for managing Hermes Agent on Railway
"""

import asyncio
import base64
import json
import os
import subprocess
import sys
from collections import deque
from datetime import datetime
from pathlib import Path

import httpx
import yaml
from starlette.applications import Starlette
from starlette.authentication import (
    AuthCredentials,
    AuthenticationBackend,
    SimpleUser,
    UnauthenticatedUser,
)
from starlette.middleware import Middleware
from starlette.middleware.authentication import AuthenticationMiddleware
from starlette.requests import Request
from starlette.responses import (
    HTMLResponse,
    JSONResponse,
    PlainTextResponse,
    RedirectResponse,
)
from starlette.routing import Mount, Route
from starlette.staticfiles import StaticFiles

# Configuration
PORT = int(os.getenv("PORT", "8080"))
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "")
HERMES_HOME = Path(os.getenv("HERMES_HOME", "/data/.hermes"))
MESSAGING_CWD = Path(os.getenv("MESSAGING_CWD", "/data/workspace"))

# Ensure directories exist
HERMES_HOME.mkdir(parents=True, exist_ok=True)
MESSAGING_CWD.mkdir(parents=True, exist_ok=True)


class BasicAuthBackend(AuthenticationBackend):
    """Basic HTTP authentication"""

    async def authenticate(self, request: Request):
        if request.url.path == "/health":
            return None

        if "authorization" not in request.headers:
            return None

        auth = request.headers["authorization"]
        if not auth.startswith("Basic "):
            return None

        try:
            decoded = base64.b64decode(auth[6:]).decode("utf-8")
            username, password = decoded.split(":", 1)
        except Exception:
            return None

        if username == ADMIN_USERNAME and password == ADMIN_PASSWORD:
            return AuthCredentials(["authenticated"]), SimpleUser(username)

        return None


class HermesManager:
    """Manages Hermes gateway subprocess"""

    def __init__(self):
        self.process = None
        self.log_buffer = deque(maxlen=1000)
        self._lock = asyncio.Lock()
        self._log_task = None

    async def start(self) -> bool:
        """Start Hermes gateway"""
        async with self._lock:
            if self.process and self.process.poll() is None:
                return False  # Already running

            try:
                self.process = subprocess.Popen(
                    ["hermes", "gateway"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    universal_newlines=True,
                    cwd=str(MESSAGING_CWD),
                    env={**os.environ, "HERMES_HOME": str(HERMES_HOME)},
                )

                # Start log collection
                self._log_task = asyncio.create_task(self._collect_logs())
                return True
            except Exception as e:
                self.log_buffer.append(f"[ERROR] Failed to start gateway: {e}")
                return False

    async def stop(self) -> bool:
        """Stop Hermes gateway"""
        async with self._lock:
            if not self.process:
                return False

            try:
                self.process.terminate()
                try:
                    self.process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    self.process.kill()
                    self.process.wait()

                if self._log_task:
                    self._log_task.cancel()
                    try:
                        await self._log_task
                    except asyncio.CancelledError:
                        pass

                self.process = None
                self._log_task = None
                return True
            except Exception as e:
                self.log_buffer.append(f"[ERROR] Failed to stop gateway: {e}")
                return False

    async def restart(self) -> bool:
        """Restart Hermes gateway"""
        await self.stop()
        await asyncio.sleep(1)
        return await self.start()

    async def _collect_logs(self):
        """Collect logs from gateway process"""
        if not self.process or not self.process.stdout:
            return

        try:
            for line in self.process.stdout:
                timestamp = datetime.now().isoformat()
                self.log_buffer.append(f"[{timestamp}] {line.rstrip()}")
        except Exception:
            pass

    def get_status(self) -> dict:
        """Get gateway status"""
        if not self.process:
            return {"running": False, "pid": None}

        return_code = self.process.poll()
        if return_code is None:
            return {"running": True, "pid": self.process.pid}
        else:
            return {"running": False, "pid": None, "exit_code": return_code}

    def get_logs(self, lines: int = 100) -> list:
        """Get recent logs"""
        return list(self.log_buffer)[-lines:]


# Global manager instance
hermes_manager = HermesManager()


class ConfigManager:
    """Manages Hermes configuration"""

    CONFIG_PATH = HERMES_HOME / "config.yaml"
    ENV_PATH = HERMES_HOME / ".env"

    @classmethod
    def get_config(cls) -> dict:
        """Read Hermes config"""
        if not cls.CONFIG_PATH.exists():
            return cls._default_config()

        try:
            with open(cls.CONFIG_PATH) as f:
                return yaml.safe_load(f) or {}
        except Exception as e:
            return {"error": str(e), "config": cls._default_config()}

    @classmethod
    def save_config(cls, config: dict) -> bool:
        """Save Hermes config"""
        try:
            with open(cls.CONFIG_PATH, "w") as f:
                yaml.dump(config, f, default_flow_style=False, sort_keys=False)
            return True
        except Exception as e:
            print(f"Failed to save config: {e}", file=sys.stderr)
            return False

    @classmethod
    def _default_config(cls) -> dict:
        """Default configuration"""
        return {
            "terminal": {
                "backend": os.getenv("HERMES_TERMINAL_BACKEND", "docker"),
                "cwd": str(MESSAGING_CWD),
                "timeout": int(os.getenv("HERMES_TERMINAL_TIMEOUT", "180")),
            },
            "compression": {"enabled": True, "threshold": 0.85},
            "models": {
                "default": os.getenv("HERMES_MODEL", "anthropic/claude-opus-4.6")
            },
        }


# =============================================================================
# Route Handlers
# =============================================================================


async def health_check(request: Request):
    """Health check endpoint for Railway"""
    gateway_status = hermes_manager.get_status()
    return JSONResponse(
        {
            "status": "healthy",
            "gateway": gateway_status,
            "timestamp": datetime.now().isoformat(),
        }
    )


async def dashboard(request: Request):
    """Main dashboard page"""
    if not request.user.is_authenticated:
        return RedirectResponse(url="/login")

    with open(Path(__file__).parent / "templates/index.html") as f:
        html = f.read()
    return HTMLResponse(html)


async def login_page(request: Request):
    """Login page"""
    with open(Path(__file__).parent / "templates/login.html") as f:
        html = f.read()
    return HTMLResponse(html)


async def api_config_get(request: Request):
    """Get Hermes configuration"""
    if not request.user.is_authenticated:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    config = ConfigManager.get_config()
    return JSONResponse(config)


async def api_config_put(request: Request):
    """Update Hermes configuration"""
    if not request.user.is_authenticated:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    try:
        body = await request.json()
        if ConfigManager.save_config(body):
            return JSONResponse({"success": True})
        else:
            return JSONResponse({"error": "Failed to save config"}, status_code=500)
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=400)


async def api_status(request: Request):
    """Get gateway and platform status"""
    if not request.user.is_authenticated:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    gateway_status = hermes_manager.get_status()

    # Check environment variables for platform configuration
    platforms = {
        "telegram": bool(os.getenv("HERMES_TELEGRAM_TOKEN")),
        "discord": bool(os.getenv("HERMES_DISCORD_TOKEN")),
        "slack": bool(os.getenv("HERMES_SLACK_BOT_TOKEN")),
        "whatsapp": os.getenv("HERMES_WHATSAPP_ENABLED", "").lower() == "true",
    }

    # Check for provider configuration
    providers = {
        "openrouter": bool(os.getenv("HERMES_OPENROUTER_API_KEY")),
        "anthropic": bool(os.getenv("HERMES_ANTHROPIC_API_KEY")),
        "openai": bool(os.getenv("HERMES_OPENAI_API_KEY")),
        "glm": bool(os.getenv("HERMES_GLM_API_KEY")),
        "kimi": bool(os.getenv("HERMES_KIMI_API_KEY")),
        "minimax": bool(os.getenv("HERMES_MINIMAX_API_KEY")),
        "nous": bool(os.getenv("HERMES_NOUS_PORTAL_KEY")),
    }

    return JSONResponse(
        {
            "gateway": gateway_status,
            "platforms": platforms,
            "providers": providers,
            "timestamp": datetime.now().isoformat(),
        }
    )


async def api_logs(request: Request):
    """Get recent gateway logs"""
    if not request.user.is_authenticated:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    lines = request.query_params.get("lines", "100")
    try:
        lines = int(lines)
    except ValueError:
        lines = 100

    logs = hermes_manager.get_logs(lines)
    return JSONResponse({"logs": logs})


async def api_gateway_start(request: Request):
    """Start Hermes gateway"""
    if not request.user.is_authenticated:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    success = await hermes_manager.start()
    return JSONResponse({"success": success, "status": hermes_manager.get_status()})


async def api_gateway_stop(request: Request):
    """Stop Hermes gateway"""
    if not request.user.is_authenticated:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    success = await hermes_manager.stop()
    return JSONResponse({"success": success, "status": hermes_manager.get_status()})


async def api_gateway_restart(request: Request):
    """Restart Hermes gateway"""
    if not request.user.is_authenticated:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    success = await hermes_manager.restart()
    return JSONResponse({"success": success, "status": hermes_manager.get_status()})


# =============================================================================
# Application Setup
# =============================================================================

middleware = [
    Middleware(
        AuthenticationMiddleware,
        backend=BasicAuthBackend(),
        on_error=lambda conn, exc: PlainTextResponse("Unauthorized", status_code=401),
    ),
]

routes = [
    Route("/", dashboard),
    Route("/login", login_page),
    Route("/health", health_check),
    Route("/api/config", api_config_get, methods=["GET"]),
    Route("/api/config", api_config_put, methods=["PUT"]),
    Route("/api/status", api_status),
    Route("/api/logs", api_logs),
    Route("/api/gateway/start", api_gateway_start, methods=["POST"]),
    Route("/api/gateway/stop", api_gateway_stop, methods=["POST"]),
    Route("/api/gateway/restart", api_gateway_restart, methods=["POST"]),
    Mount(
        "/static",
        StaticFiles(directory=Path(__file__).parent / "templates/static"),
        name="static",
    ),
]

app = Starlette(routes=routes, middleware=middleware)

if __name__ == "__main__":
    import uvicorn

    print(f"Starting Hermes Railway Dashboard on port {PORT}")
    print(f"Hermes home: {HERMES_HOME}")
    print(f"Workspace: {MESSAGING_CWD}")
    uvicorn.run(app, host="0.0.0.0", port=PORT)
