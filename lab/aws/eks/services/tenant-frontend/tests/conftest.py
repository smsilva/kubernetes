import pytest
import jwt
from fastapi.testclient import TestClient

_SECRET = "test-secret"

SAMPLE_CLAIMS = {
    "name": "Silvio Silva",
    "email": "silvio@example.com",
    "custom:tenant_id": "customer1",
    "sub": "abc123-uuid",
    "iss": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_test",
    "aud": "client-id-test",
}

SAMPLE_TOKEN = jwt.encode(SAMPLE_CLAIMS, _SECRET, algorithm="HS256")

SAMPLE_HTTPBIN_RESPONSE = {
    "args": {},
    "headers": {
        "Accept": "*/*",
        "Host": "httpbin:8000",
        "User-Agent": "python-httpx/0.27.0",
    },
    "origin": "10.0.0.1",
    "url": "http://httpbin:8000/get",
}


@pytest.fixture(autouse=True)
def set_env_vars(monkeypatch):
    monkeypatch.setenv("HTTPBIN_URL", "http://httpbin-mock:8000")
    monkeypatch.setenv("PLATFORM_URL", "https://wasp.silvios.me")
    monkeypatch.setenv("LOG_LEVEL", "INFO")


@pytest.fixture
def api_client():
    from app.main import app
    return TestClient(app, follow_redirects=False)


@pytest.fixture
def authenticated_client(api_client):
    """TestClient with session cookie pre-set."""
    api_client.cookies.set("session", SAMPLE_TOKEN)
    return api_client
