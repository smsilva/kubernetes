import os
from pathlib import Path

from fastapi import Depends, FastAPI, Query
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.requests import Request

from .cognito import CognitoClient, CognitoTokenExchangeError
from .state import InvalidStateError, LoginState, decode_state_token

app = FastAPI(title="Callback Handler", version="1.0.0")

app.mount("/static", StaticFiles(directory=Path(__file__).parent / "static"), name="static")
templates = Jinja2Templates(directory=Path(__file__).parent / "templates")


def get_cognito_client() -> CognitoClient:
    """Substituída em testes via app.dependency_overrides."""
    raise NotImplementedError


def _build_cognito_client(client_id: str, client_secret: str) -> CognitoClient:
    return CognitoClient(
        domain=os.getenv("COGNITO_DOMAIN", ""),
        client_id=client_id,
        client_secret=client_secret,
        callback_url=os.getenv("CALLBACK_URL", ""),
    )


def _render_error(request: Request, message: str, status_code: int = 400):
    return templates.TemplateResponse(
        request=request,
        name="error.html",
        context={"message": message},
        status_code=status_code,
    )


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

    override = app.dependency_overrides.get(get_cognito_client)
    try:
        tenant_key = login_state.tenant_id.upper()
        client_secret = os.environ[f"COGNITO_CLIENT_SECRET_{tenant_key}"]
    except KeyError:
        return _render_error(request, "Tenant not configured.", status_code=500)

    if override:
        cognito = override()
        cognito.with_credentials(login_state.client_id, client_secret)
    else:
        cognito = _build_cognito_client(login_state.client_id, client_secret)

    try:
        tokens = cognito.exchange_code_for_tokens(code)
    except CognitoTokenExchangeError:
        return _render_error(request, "Could not complete authentication. Please try again.")

    response = RedirectResponse(url=login_state.return_url, status_code=302)
    response.set_cookie(
        key="session",
        value=tokens.id_token,
        httponly=True,
        samesite="lax",
        secure=True,
        domain=".wasp.silvios.me",
    )
    return response
