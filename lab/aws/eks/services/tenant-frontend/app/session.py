import logging

import jwt
from fastapi import Request

_logger = logging.getLogger(__name__)


def decode_session(request: Request) -> dict | None:
    """Decode the session cookie (Cognito ID token) without signature verification."""
    token = request.cookies.get("session")
    if not token:
        return None
    try:
        return jwt.decode(
            token,
            options={"verify_signature": False},
            algorithms=["RS256", "HS256"],
        )
    except Exception as exc:
        _logger.warning("Failed to decode session cookie: %s", exc)
        return None
