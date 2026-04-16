import logging
import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from app.session import decode_session

# ── Logging ──────────────────────────────────────────────────────────────────
_log_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO)
logging.basicConfig(level=_log_level)
logging.getLogger().setLevel(_log_level)

_logger = logging.getLogger(__name__)

# ── Config ───────────────────────────────────────────────────────────────────
HTTPBIN_URL = os.getenv("HTTPBIN_URL", "http://httpbin.wasp.local:32080")
PLATFORM_URL = os.getenv("PLATFORM_URL", "https://wasp.silvios.me")
CUSTOMER1_URL = os.getenv("CUSTOMER1_URL", "https://customer1.wasp.silvios.me")
CUSTOMER2_URL = os.getenv("CUSTOMER2_URL", "https://customer2.wasp.silvios.me")

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(title="WASP Tenant Frontend", version="1.0.0")

_static_dir = Path(__file__).parent / "static"
_templates_dir = Path(__file__).parent / "templates"

app.mount("/static", StaticFiles(directory=_static_dir, follow_symlink=True), name="static")
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
def test_page(request: Request):
    claims = _require_session(request)
    if claims is None:
        return RedirectResponse(url=PLATFORM_URL, status_code=302)

    tenant_id = claims.get("custom:tenant_id", "")
    session_token = request.cookies.get("session", "")

    def _curl(url: str, *, with_jwt: bool = True) -> str:
        parts = ["curl -i"]
        if with_jwt and session_token:
            parts.append(f"  -H 'Authorization: Bearer {session_token}'")
        parts.append(f"  '{url}'")
        return " \\\n".join(parts)

    def _case(label, url, expected, *, with_jwt: bool = True, group: str = ""):
        return {
            "label":    label,
            "url":      url,
            "expected": expected,
            "with_jwt": with_jwt,
            "curl_cmd": _curl(url, with_jwt=with_jwt),
            "group":    group,
        }

    is_c1 = tenant_id == "customer1"

    test_cases = [
        _case("httpbin",           f"{HTTPBIN_URL}/get",           200,                  group="Own Tenant"),
        _case("customer1-health",  f"{CUSTOMER1_URL}/health",      200, with_jwt=False,  group="Own Tenant"    if is_c1 else "Cross-Tenant"),
        _case("customer2-health",  f"{CUSTOMER2_URL}/health",      200, with_jwt=False,  group="Cross-Tenant"  if is_c1 else "Own Tenant"),
        _case("customer1-httpbin", f"{CUSTOMER1_URL}/httpbin/get", 200 if is_c1 else 403, group="Own Tenant"   if is_c1 else "Cross-Tenant"),
        _case("customer2-httpbin", f"{CUSTOMER2_URL}/httpbin/get", 200 if not is_c1 else 403, group="Cross-Tenant" if is_c1 else "Own Tenant"),
    ]

    return templates.TemplateResponse(
        request=request,
        name="test.html",
        context={
            "test_cases":  test_cases,
            "jwt_token":   session_token,
            "name":        claims.get("name", "User"),
            "tenant_id":   tenant_id,
        },
    )


@app.get("/profile")
def profile(request: Request):
    claims = _require_session(request)
    if claims is None:
        return RedirectResponse(url=PLATFORM_URL, status_code=302)

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
