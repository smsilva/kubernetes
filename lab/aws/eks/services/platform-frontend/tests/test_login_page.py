from tests.conftest import CUSTOMER1_TENANT


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
