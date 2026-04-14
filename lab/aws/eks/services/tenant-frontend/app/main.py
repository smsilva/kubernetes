import logging
import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from app.http import fetch_url
from app.session import decode_session

# ── Logging ──────────────────────────────────────────────────────────────────
_log_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO)
logging.basicConfig(level=_log_level)
logging.getLogger().setLevel(_log_level)

_logger = logging.getLogger(__name__)

# ── Config ───────────────────────────────────────────────────────────────────
HTTPBIN_URL = os.getenv("HTTPBIN_URL", "http://httpbin:8000")
PLATFORM_URL = os.getenv("PLATFORM_URL", "https://wasp.silvios.me")

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(title="WASP Tenant Frontend", version="1.0.0")

_static_dir = Path(__file__).parent / "static"
_templates_dir = Path(__file__).parent / "templates"

app.mount("/static", StaticFiles(directory=_static_dir), name="static")
templates = Jinja2Templates(directory=_templates_dir)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _require_session(request: Request) -> dict | None:
    """Return claims dict or None (caller must redirect to PLATFORM_URL on None)."""
    return decode_session(request)


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/")
def home(request: Request):
    claims = _require_session(request)
    if claims is None:
        return RedirectResponse(url=PLATFORM_URL, status_code=302)

    return templates.TemplateResponse(
        request=request,
        name="home.html",
        context={
            "name": claims.get("name", "User"),
            "email": claims.get("email", ""),
            "tenant_id": claims.get("custom:tenant_id", ""),
        },
    )


@app.get("/test")
async def test_page(request: Request):
    claims = _require_session(request)
    if claims is None:
        return RedirectResponse(url=PLATFORM_URL, status_code=302)

    result = await fetch_url(f"{HTTPBIN_URL}/get")

    return templates.TemplateResponse(
        request=request,
        name="test.html",
        context={
            "result_json": result["result_json"],
            "error": result["error"],
            "httpbin_url": result["url"],
            "name": claims.get("name", "User"),
            "tenant_id": claims.get("custom:tenant_id", ""),
        },
    )


@app.get("/profile")
def profile(request: Request):
    claims = _require_session(request)
    if claims is None:
        return RedirectResponse(url=PLATFORM_URL, status_code=302)

    # Priority claims shown first; rest appended in order
    priority_keys = ["name", "email", "custom:tenant_id", "sub"]
    priority = [(k, claims[k]) for k in priority_keys if k in claims]
    rest = [(k, v) for k, v in claims.items() if k not in priority_keys]

    return templates.TemplateResponse(
        request=request,
        name="profile.html",
        context={
            "priority_claims": priority,
            "other_claims": rest,
            "name": claims.get("name", "User"),
            "tenant_id": claims.get("custom:tenant_id", ""),
        },
    )


@app.get("/logout")
def logout():
    response = RedirectResponse(url=PLATFORM_URL, status_code=302)
    response.delete_cookie(
        key="session",
        domain=".wasp.silvios.me",
        path="/",
        secure=True,
        httponly=True,
        samesite="lax",
    )
    return response
