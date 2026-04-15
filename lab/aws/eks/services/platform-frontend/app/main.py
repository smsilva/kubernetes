import logging
import os
from pathlib import Path

from fastapi import Depends, FastAPI, Form, Request
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from .auth import build_cognito_authorize_url, build_state_token
from .discovery_client import DiscoveryClient, TenantInfo

_log_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO)
logging.basicConfig(level=_log_level)
logging.getLogger().setLevel(_log_level)

app = FastAPI(title="Platform Frontend", version="1.0.0")

app.mount("/static", StaticFiles(directory=Path(__file__).parent / "static"), name="static")
templates = Jinja2Templates(directory=Path(__file__).parent / "templates")


def get_discovery_client() -> DiscoveryClient:
    return DiscoveryClient(os.getenv("DISCOVERY_URL", "http://discovery:8000"))


def _is_valid_email(email: str) -> bool:
    parts = email.split("@")
    return len(parts) == 2 and "." in parts[1]


def _render_login(request: Request, error: str = "", email: str = ""):
    return templates.TemplateResponse(
        request=request,
        name="login.html",
        context={"error": error, "email": email},
    )


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/")
def login_page(request: Request):
    return _render_login(request)


@app.post("/login")
def process_login(
    request: Request,
    email: str = Form(...),
    discovery: DiscoveryClient = Depends(get_discovery_client),
):
    if not _is_valid_email(email):
        return _render_login(request, error="Please enter a valid email address.", email=email)

    domain = email.split("@")[1]
    tenant: TenantInfo | None = discovery.find_tenant_by_domain(domain)

    if not tenant:
        return _render_login(
            request,
            error=f"No account found for {domain}. Contact your administrator.",
            email=email,
        )

    tenant_url = tenant.tenant_url
    return_url = tenant_url if "://" in tenant_url else f"https://{tenant_url}"

    state = build_state_token(
        tenant_id=tenant.tenant_id,
        client_id=tenant.client_id,
        return_url=return_url,
        secret=os.getenv("STATE_JWT_SECRET", ""),
    )

    redirect_url = build_cognito_authorize_url(
        cognito_domain=os.getenv("COGNITO_DOMAIN", ""),
        client_id=tenant.client_id,
        idp_name=tenant.idp_name,
        callback_url=os.getenv("CALLBACK_URL", ""),
        state=state,
        authorize_url=os.getenv("IDP_AUTHORIZE_URL", ""),
    )

    return RedirectResponse(url=redirect_url, status_code=302)
