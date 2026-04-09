from tests.conftest import SAMPLE_STATE


def test_health_check_returns_200(api_client):
    response = api_client.get("/health")

    assert response.status_code == 200


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
