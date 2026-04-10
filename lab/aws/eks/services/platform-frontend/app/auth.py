import secrets
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode

import jwt


def build_state_token(tenant_id: str, client_id: str, return_url: str, secret: str) -> str:
    payload = {
        "tenant_id": tenant_id,
        "client_id": client_id,
        "return_url": return_url,
        "nonce": secrets.token_urlsafe(16),
        "exp": datetime.now(timezone.utc) + timedelta(minutes=10),
    }
    return jwt.encode(payload, secret, algorithm="HS256")


def build_cognito_authorize_url(
    cognito_domain: str,
    client_id: str,
    idp_name: str,
    callback_url: str,
    state: str,
) -> str:
    params = {
        "client_id": client_id,
        "identity_provider": idp_name,
        "redirect_uri": callback_url,
        "response_type": "code",
        "scope": "openid email profile",
        "state": state,
    }
    return f"https://{cognito_domain}/oauth2/authorize?{urlencode(params)}"
