import time
from unittest.mock import patch, MagicMock

import jwt
from fastapi.testclient import TestClient

from app.main import app, get_cognito_client
from tests.conftest import SAMPLE_STATE, SECRET


def test_health_check_returns_200(api_client):
    response = api_client.get("/health")

    assert response.status_code == 200


def test_shared_tokens_css_accessible(api_client):
    response = api_client.get("/static/shared/tokens.css")

    assert response.status_code == 200
    assert "--color-primary" in response.text


def test_shared_base_css_accessible(api_client):
    response = api_client.get("/static/shared/base.css")

    assert response.status_code == 200
    assert ".theme-toggle" in response.text


def test_callback_redirects_to_tenant_url_on_success(api_client, mock_cognito_success):
    response = api_client.get(f"/callback?code=valid-code&state={SAMPLE_STATE}")

    assert response.status_code == 302
    assert response.headers["location"] == "https://customer1.wasp.silvios.me"


def test_callback_sets_session_cookie_on_success(api_client, mock_cognito_success):
    response = api_client.get(f"/callback?code=valid-code&state={SAMPLE_STATE}")

    cookie = response.headers.get("set-cookie", "")
    assert "session=" in cookie
    assert "HttpOnly" in cookie
    assert "SameSite=lax" in cookie


def test_callback_returns_error_page_when_code_is_missing(api_client, mock_cognito_success):
    response = api_client.get(f"/callback?state={SAMPLE_STATE}")

    assert response.status_code == 422


def test_callback_returns_error_page_when_state_is_invalid(api_client, mock_cognito_success):
    response = api_client.get("/callback?code=valid-code&state=invalid-state")

    assert response.status_code == 400


def test_callback_returns_error_page_when_token_exchange_fails(api_client, mock_cognito_failure):
    response = api_client.get(f"/callback?code=bad-code&state={SAMPLE_STATE}")

    assert response.status_code == 400


def test_callback_uses_client_id_from_state_jwt(api_client, mock_cognito_success, monkeypatch):
    monkeypatch.setenv("IDP_CLIENT_SECRET_CUSTOMER1", "secret-for-customer1")
    state = jwt.encode(
        {"tenant_id": "customer1", "client_id": "client-from-state", "return_url": "https://customer1.wasp.silvios.me", "nonce": "n", "exp": int(time.time()) + 600},
        SECRET,
        algorithm="HS256",
    )

    response = api_client.get(f"/callback?code=valid-code&state={state}")

    assert response.status_code == 302
    assert mock_cognito_success.last_client_id == "client-from-state"


def test_callback_uses_correct_secret_for_tenant(api_client, mock_cognito_success, monkeypatch):
    monkeypatch.setenv("IDP_CLIENT_SECRET_CUSTOMER1", "secret-for-customer1")
    state = jwt.encode(
        {"tenant_id": "customer1", "client_id": "any-client", "return_url": "https://customer1.wasp.silvios.me", "nonce": "n", "exp": int(time.time()) + 600},
        SECRET,
        algorithm="HS256",
    )

    response = api_client.get(f"/callback?code=valid-code&state={state}")

    assert response.status_code == 302
    assert mock_cognito_success.last_client_secret == "secret-for-customer1"


def test_callback_returns_500_when_tenant_secret_not_configured(api_client, mock_cognito_success):
    state = jwt.encode(
        {"tenant_id": "unknowntenant", "client_id": "any-client", "return_url": "https://x.wasp.silvios.me", "nonce": "n", "exp": int(time.time()) + 600},
        SECRET,
        algorithm="HS256",
    )
    client = TestClient(app, raise_server_exceptions=False)

    response = client.get(f"/callback?code=valid-code&state={state}")

    assert response.status_code == 500


def test_callback_returns_403_when_tenant_id_in_token_differs_from_state(api_client):
    import jwt as _jwt
    from app.cognito import CognitoTokens
    from tests.conftest import MockCognitoClient

    wrong_tenant_token = _jwt.encode(
        {"sub": "user-456", "email": "user@other.com", "custom:tenant_id": "customer2"},
        "any-secret-long-enough-for-hs256-hmac-key",
        algorithm="HS256",
    )
    tokens = CognitoTokens(id_token=wrong_tenant_token, access_token="a", refresh_token="r")
    app.dependency_overrides[get_cognito_client] = lambda: MockCognitoClient(tokens=tokens)

    response = api_client.get(f"/callback?code=valid-code&state={SAMPLE_STATE}")

    assert response.status_code == 403
    app.dependency_overrides.clear()


def test_callback_returns_400_when_token_has_no_tenant_id(api_client):
    import jwt as _jwt
    from app.cognito import CognitoTokens
    from tests.conftest import MockCognitoClient

    no_tenant_token = _jwt.encode(
        {"sub": "user-789", "email": "user@other.com"},
        "any-secret-long-enough-for-hs256-hmac-key",
        algorithm="HS256",
    )
    tokens = CognitoTokens(id_token=no_tenant_token, access_token="a", refresh_token="r")
    app.dependency_overrides[get_cognito_client] = lambda: MockCognitoClient(tokens=tokens)

    response = api_client.get(f"/callback?code=valid-code&state={SAMPLE_STATE}")

    assert response.status_code == 400
    app.dependency_overrides.clear()


def test_cognito_client_uses_idp_token_url_when_set():
    from app.cognito import CognitoClient

    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "id_token": "id",
        "access_token": "access",
        "refresh_token": "refresh",
    }

    custom_token_url = "http://idp.wasp.local:32080/realms/wasp/protocol/openid-connect/token"
    client = CognitoClient(
        domain="idp.wasp.local",
        client_id="wasp-platform",
        client_secret="secret",
        callback_url="http://auth.wasp.local:32080/callback",
        token_url=custom_token_url,
    )

    with patch("app.cognito.httpx.post", return_value=mock_response) as mock_post:
        client.exchange_code_for_tokens("some-code")
        called_url = mock_post.call_args[0][0]
        assert called_url == custom_token_url


def test_cognito_client_defaults_to_cognito_token_url_when_token_url_not_set():
    from app.cognito import CognitoClient

    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "id_token": "id",
        "access_token": "access",
        "refresh_token": "refresh",
    }

    client = CognitoClient(
        domain="idp.wasp.silvios.me",
        client_id="abc123",
        client_secret="secret",
        callback_url="https://auth.wasp.silvios.me/callback",
    )

    with patch("app.cognito.httpx.post", return_value=mock_response) as mock_post:
        client.exchange_code_for_tokens("some-code")
        called_url = mock_post.call_args[0][0]
        assert called_url == "https://idp.wasp.silvios.me/oauth2/token"


def test_build_cognito_client_uses_idp_token_url_env_var(monkeypatch):
    from app.main import _build_cognito_client

    monkeypatch.setenv("IDP_TOKEN_URL", "http://idp.wasp.local:32080/realms/wasp/protocol/openid-connect/token")

    client = _build_cognito_client("wasp-platform", "secret")

    assert client._token_url == "http://idp.wasp.local:32080/realms/wasp/protocol/openid-connect/token"


def test_callback_cookie_not_secure_when_cookie_secure_is_false(api_client, mock_cognito_success, monkeypatch):
    monkeypatch.setenv("COOKIE_SECURE", "false")

    response = api_client.get(f"/callback?code=valid-code&state={SAMPLE_STATE}")

    cookie = response.headers.get("set-cookie", "")
    assert "Secure" not in cookie


def test_callback_cookie_is_secure_by_default(api_client, mock_cognito_success):
    response = api_client.get(f"/callback?code=valid-code&state={SAMPLE_STATE}")

    cookie = response.headers.get("set-cookie", "")
    assert "Secure" in cookie


def test_callback_cookie_uses_domain_from_env(api_client, mock_cognito_success, monkeypatch):
    monkeypatch.setenv("COOKIE_DOMAIN", ".wasp.local")

    response = api_client.get(f"/callback?code=valid-code&state={SAMPLE_STATE}")

    cookie = response.headers.get("set-cookie", "")
    assert "Domain=.wasp.local" in cookie


def test_callback_cookie_uses_default_domain_when_env_not_set(api_client, mock_cognito_success):
    response = api_client.get(f"/callback?code=valid-code&state={SAMPLE_STATE}")

    cookie = response.headers.get("set-cookie", "")
    assert "Domain=.wasp.silvios.me" in cookie
