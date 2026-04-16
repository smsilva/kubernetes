import time

import jwt
import pytest
from fastapi.testclient import TestClient

from app.cognito import CognitoClient, CognitoTokens
from app.main import app, get_cognito_client

SECRET = "test-secret-key-long-enough-for-hs256"
IDP_DOMAIN = "auth.wasp.silvios.me"
CALLBACK_URL = "https://auth.wasp.silvios.me/callback"

SAMPLE_STATE = jwt.encode(
    {
        "tenant_id": "customer1",
        "client_id": "abc123client",
        "return_url": "https://customer1.wasp.silvios.me",
        "nonce": "abc123",
        "exp": int(time.time()) + 600,
    },
    SECRET,
    algorithm="HS256",
)

SAMPLE_ID_TOKEN = jwt.encode(
    {"sub": "user-123", "email": "smsilva@gmail.com", "custom:tenant_id": "customer1"},
    "any-secret-long-enough-for-hs256-hmac-key",
    algorithm="HS256",
)

MISMATCHED_ID_TOKEN = jwt.encode(
    {"sub": "user-456", "email": "user@other-company.com", "custom:tenant_id": "customer1"},
    "any-secret-long-enough-for-hs256-hmac-key",
    algorithm="HS256",
)


class MockCognitoClient:
    def __init__(self, tokens: CognitoTokens | None = None, raises: Exception | None = None):
        self._tokens = tokens
        self._raises = raises
        self.last_client_id: str | None = None
        self.last_client_secret: str | None = None

    def with_credentials(self, client_id: str, client_secret: str) -> "MockCognitoClient":
        self.last_client_id = client_id
        self.last_client_secret = client_secret
        return self

    def exchange_code_for_tokens(self, code: str) -> CognitoTokens:
        if self._raises:
            raise self._raises
        return self._tokens


@pytest.fixture(autouse=True)
def set_env_vars(monkeypatch):
    monkeypatch.setenv("IDP_DOMAIN", IDP_DOMAIN)
    monkeypatch.setenv("IDP_CLIENT_SECRET_CUSTOMER1", "supersecret")
    monkeypatch.setenv("CALLBACK_URL", CALLBACK_URL)
    monkeypatch.setenv("STATE_JWT_SECRET", SECRET)


@pytest.fixture
def mock_cognito_success():
    tokens = CognitoTokens(
        id_token=SAMPLE_ID_TOKEN,
        access_token="access-token",
        refresh_token="refresh-token",
    )
    client = MockCognitoClient(tokens=tokens)
    app.dependency_overrides[get_cognito_client] = lambda: client
    yield client
    app.dependency_overrides.clear()


@pytest.fixture
def mock_cognito_failure():
    from app.cognito import CognitoTokenExchangeError
    client = MockCognitoClient(raises=CognitoTokenExchangeError("invalid code"))
    app.dependency_overrides[get_cognito_client] = lambda: client
    yield client
    app.dependency_overrides.clear()


@pytest.fixture
def api_client():
    return TestClient(app, follow_redirects=False)
