import time

import jwt
import pytest

from app.state import InvalidStateError, LoginState, decode_state_token
from tests.conftest import SECRET


def _make_token(overrides: dict = {}) -> str:
    payload = {
        "tenant_id": "customer1",
        "client_id": "abc123client",
        "return_url": "https://customer1.wasp.silvios.me",
        "nonce": "abc123",
        "exp": int(time.time()) + 600,
        **overrides,
    }
    return jwt.encode(payload, SECRET, algorithm="HS256")


def test_decode_returns_login_state_for_valid_token():
    token = _make_token()

    state = decode_state_token(token, SECRET)

    assert isinstance(state, LoginState)
    assert state.tenant_id == "customer1"
    assert state.return_url == "https://customer1.wasp.silvios.me"
    assert state.nonce == "abc123"


def test_decode_raises_for_expired_token():
    token = _make_token({"exp": int(time.time()) - 1})

    with pytest.raises(InvalidStateError):
        decode_state_token(token, SECRET)


def test_decode_raises_for_wrong_secret():
    token = _make_token()

    with pytest.raises(InvalidStateError):
        decode_state_token(token, "wrong-secret-long-enough-for-hs256-hmac-key")


def test_decode_raises_for_missing_required_claim():
    token = jwt.encode({"exp": int(time.time()) + 600}, SECRET, algorithm="HS256")

    with pytest.raises(InvalidStateError):
        decode_state_token(token, SECRET)


def test_decode_exposes_client_id_from_token():
    token = _make_token({"client_id": "abc123client"})

    state = decode_state_token(token, SECRET)

    assert state.client_id == "abc123client"


def test_decode_raises_when_client_id_is_missing():
    token = jwt.encode(
        {"tenant_id": "customer1", "return_url": "https://x.me", "nonce": "n", "exp": int(time.time()) + 600},
        SECRET,
        algorithm="HS256",
    )

    with pytest.raises(InvalidStateError):
        decode_state_token(token, SECRET)
