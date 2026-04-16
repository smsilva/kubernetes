import logging
import os
from pathlib import Path

import jwt as pyjwt
from fastapi import FastAPI, Query
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.requests import Request

from .cognito import CognitoClient, CognitoTokenExchangeError
from .state import InvalidStateError, decode_state_token

_log_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO)
logging.basicConfig(level=_log_level)
logging.getLogger().setLevel(_log_level)

app = FastAPI(title="Callback Handler", version="1.0.0")

app.mount("/static", StaticFiles(directory=Path(__file__).parent / "static", follow_symlink=True), name="static")
templates = Jinja2Templates(directory=Path(__file__).parent / "templates")


def get_cognito_client() -> CognitoClient:
    """Substituída em testes via app.dependency_overrides."""
    raise NotImplementedError


def _build_cognito_client(client_id: str, client_secret: str) -> CognitoClient:
    return CognitoClient(
        domain=os.getenv("IDP_DOMAIN", ""),
        client_id=client_id,
        client_secret=client_secret,
        callback_url=os.getenv("CALLBACK_URL", ""),
        token_url=os.getenv("IDP_TOKEN_URL", ""),
    )


def _render_error(request: Request, message: str, status_code: int = 400):
    login_url = os.getenv("PLATFORM_URL", "/")
    return templates.TemplateResponse(
        request=request,
        name="error.html",
        context={"message": message, "login_url": login_url},
        status_code=status_code,
    )


def _extract_tenant_id(id_token: str) -> str | None:
    """Extrai custom:tenant_id injetado pelo Pre-Token Generation Lambda do Cognito."""
    try:
        claims = pyjwt.decode(
            id_token,
            options={"verify_signature": False},
            algorithms=["RS256", "HS256"],
        )
    except pyjwt.DecodeError:
        return None
    return claims.get("custom:tenant_id")


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/callback")
def handle_callback(
    request: Request,
    code: str = Query(...),
    state: str = Query(...),
):
    try:
        login_state = decode_state_token(state, os.getenv("STATE_JWT_SECRET", ""))
    except InvalidStateError:
        return _render_error(request, "The authentication session is invalid or has expired.")

    cognito_override = app.dependency_overrides.get(get_cognito_client)
    try:
        tenant_key = login_state.tenant_id.upper()
        client_secret = os.environ[f"IDP_CLIENT_SECRET_{tenant_key}"]
    except KeyError:
        return _render_error(request, "Tenant not configured.", status_code=500)

    if cognito_override:
        cognito = cognito_override()
        cognito.with_credentials(login_state.client_id, client_secret)
    else:
        cognito = _build_cognito_client(login_state.client_id, client_secret)

    try:
        tokens = cognito.exchange_code_for_tokens(code)
    except CognitoTokenExchangeError:
        return _render_error(request, "Could not complete authentication. Please try again.")

    actual_tenant = _extract_tenant_id(tokens.id_token)
    if not actual_tenant:
        return _render_error(request, "Could not determine tenant from authentication token.")

    if actual_tenant != login_state.tenant_id:
        return _render_error(
            request,
            "Your account is not authorized for this tenant.",
            status_code=403,
        )

    cookie_secure = os.getenv("COOKIE_SECURE", "true").lower() != "false"
    cookie_domain = os.getenv("COOKIE_DOMAIN", ".wasp.silvios.me")

    response = RedirectResponse(url=login_state.return_url, status_code=302)
    response.set_cookie(
        key="session",
        value=tokens.id_token,
        httponly=True,
        samesite="lax",
        secure=cookie_secure,
        domain=cookie_domain,
    )
    return response
