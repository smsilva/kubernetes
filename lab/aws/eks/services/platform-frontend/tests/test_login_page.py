import jwt

from app.auth import build_state_token
from tests.conftest import CUSTOMER1_TENANT


def test_state_token_includes_client_id():
    token = build_state_token(
        tenant_id="customer1",
        client_id="abc123client",
        return_url="https://customer1.wasp.silvios.me",
        secret="a-secret-key-long-enough-for-hmac",
    )
    payload = jwt.decode(token, "a-secret-key-long-enough-for-hmac", algorithms=["HS256"])

    assert payload["client_id"] == "abc123client"


def test_login_page_renders_email_form(api_client):
    response = api_client.get("/")

    assert response.status_code == 200
    assert 'type="email"' in response.text
    assert 'name="email"' in response.text


def test_login_page_displays_wasp_platform_branding(api_client):
    response = api_client.get("/")

    assert "WASP" in response.text
    assert "Sign in" in response.text


def test_post_login_redirects_to_cognito_when_tenant_is_found(api_client, mock_discovery_with_customer1):
    response = api_client.post("/login", data={"email": "smsilva@gmail.com"})

    assert response.status_code == 302
    location = response.headers["location"]
    assert "auth.wasp.silvios.me/oauth2/authorize" in location
    assert f"client_id={CUSTOMER1_TENANT.client_id}" in location
    assert "response_type=code" in location
    assert "state=" in location


def test_post_login_shows_error_when_domain_is_not_registered(api_client, mock_discovery_returns_none):
    response = api_client.post("/login", data={"email": "user@notregistered.com"})

    assert response.status_code == 200
    assert "notregistered.com" in response.text


def test_post_login_preserves_email_in_form_on_error(api_client, mock_discovery_returns_none):
    response = api_client.post("/login", data={"email": "user@notregistered.com"})

    assert response.status_code == 200
    assert "user@notregistered.com" in response.text


def test_post_login_shows_error_when_email_format_is_invalid(api_client):
    response = api_client.post("/login", data={"email": "not-an-email"})

    assert response.status_code == 200
    assert "valid email" in response.text.lower()


def test_health_check_returns_200(api_client):
    response = api_client.get("/health")

    assert response.status_code == 200


def test_post_login_uses_idp_authorize_url_when_set(api_client, mock_discovery_with_customer1, monkeypatch):
    monkeypatch.setenv("IDP_AUTHORIZE_URL", "http://idp.wasp.local:32080/realms/wasp/protocol/openid-connect/auth")

    response = api_client.post("/login", data={"email": "smsilva@gmail.com"})

    assert response.status_code == 302
    location = response.headers["location"]
    assert location.startswith("http://idp.wasp.local:32080/realms/wasp/protocol/openid-connect/auth")


def test_post_login_omits_identity_provider_when_idp_name_is_empty(api_client, mock_discovery_no_idp):
    response = api_client.post("/login", data={"email": "user@customer1.com"})

    assert response.status_code == 302
    location = response.headers["location"]
    assert "identity_provider" not in location


def _decode_state_from_location(location: str, secret: str) -> dict:
    from urllib.parse import urlparse, parse_qs
    import jwt as _jwt
    qs = parse_qs(urlparse(location).query)
    state_token = qs["state"][0]
    return _jwt.decode(state_token, secret, algorithms=["HS256"])


def test_post_login_return_url_prepends_https_when_tenant_url_has_no_scheme(
    api_client, mock_discovery_with_customer1
):
    response = api_client.post("/login", data={"email": "smsilva@gmail.com"})

    assert response.status_code == 302
    payload = _decode_state_from_location(
        response.headers["location"], "test-secret-key-long-enough-for-hs256"
    )
    assert payload["return_url"] == "https://customer1.wasp.silvios.me"


def test_post_login_return_url_uses_tenant_url_as_is_when_scheme_present(
    api_client, mock_discovery_with_full_url
):
    response = api_client.post("/login", data={"email": "user@customer1.com"})

    assert response.status_code == 302
    payload = _decode_state_from_location(
        response.headers["location"], "test-secret-key-long-enough-for-hs256"
    )
    assert payload["return_url"] == "http://customer1.wasp.local:32080"
