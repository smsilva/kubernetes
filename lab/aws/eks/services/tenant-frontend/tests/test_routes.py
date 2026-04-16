import re
import pytest

from tests.conftest import SAMPLE_TOKEN


# ── Health ──────────────────────────────────────────────────────────────────

def test_health_check_returns_200(api_client):
    response = api_client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_shared_tokens_css_accessible(api_client):
    response = api_client.get("/static/shared/tokens.css")

    assert response.status_code == 200
    assert "--color-primary" in response.text


def test_shared_base_css_accessible(api_client):
    response = api_client.get("/static/shared/base.css")

    assert response.status_code == 200
    assert ".theme-toggle" in response.text


# ── Home (/) ────────────────────────────────────────────────────────────────

def test_home_redirects_when_no_session_cookie(api_client):
    response = api_client.get("/")
    assert response.status_code == 302
    assert "wasp.silvios.me" in response.headers["location"]


def test_home_renders_with_valid_session(authenticated_client):
    response = authenticated_client.get("/")
    assert response.status_code == 200
    body = response.text
    assert "Silvio Silva" in body
    assert "customer1" in body


# ── Test (/test) ─────────────────────────────────────────────────────────────

def test_test_page_redirects_when_no_session(api_client):
    response = api_client.get("/test")
    assert response.status_code == 302


def test_test_page_renders_with_valid_session(authenticated_client):
    response = authenticated_client.get("/test")
    assert response.status_code == 200


def test_test_page_embeds_jwt_token(authenticated_client):
    """JWT token must be embedded in the page for client-side Authorization headers."""
    response = authenticated_client.get("/test")
    assert SAMPLE_TOKEN in response.text


def test_test_page_embeds_five_test_cases(authenticated_client):
    """Server embeds all 5 test case URLs in the page; browser runs them."""
    response = authenticated_client.get("/test")
    body = response.text
    assert "httpbin.wasp.local:32080" in body
    assert "customer1-mock.wasp.silvios.me/health" in body
    assert "customer2-mock.wasp.silvios.me/health" in body
    assert "customer1-mock.wasp.silvios.me/httpbin/get" in body
    assert "customer2-mock.wasp.silvios.me/httpbin/get" in body


def test_test_page_starts_with_all_idle(authenticated_client):
    """Page loads with all tests idle — no results until browser runs them.

    status-pass and status-fail appear in the results-summary legend (static HTML),
    so we verify the accordion items section only, which ends before results-summary.
    """
    response = authenticated_client.get("/test")
    body = response.text
    accordion_section = body.split('class="results-summary"')[0]
    assert "status-idle" in accordion_section
    assert "status-pass" not in accordion_section
    assert "status-fail" not in accordion_section


def test_test_page_url_preserves_lowercase(authenticated_client):
    response = authenticated_client.get("/test")
    body = response.text
    assert 'text-transform: none' in body or 'url-text' in body


def test_test_page_has_accordion_structure(authenticated_client):
    response = authenticated_client.get("/test")
    body = response.text
    assert "accordion-header" in body
    assert "accordion-body" in body


def test_test_page_includes_curl_commands(authenticated_client):
    """Each test entry must include a curl_cmd with the JWT Bearer token."""
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "curl" in body
    assert f"Bearer {SAMPLE_TOKEN}" in body


def test_curl_command_uses_curl_i(authenticated_client):
    """curl commands must use -i (show headers+body) not -s -o /dev/null."""
    response = authenticated_client.get("/test")
    body = response.text
    assert "curl -i" in body
    assert "curl -s" not in body


def test_health_test_curl_commands_omit_jwt(authenticated_client):
    """Health endpoints are open — their curl commands must not carry a JWT."""
    response = authenticated_client.get("/test")
    body = response.text
    curl_blocks = dict(re.findall(r'<pre class="curl-code" id="curl-([^"]+)">([^<]+)</pre>', body))
    assert "Authorization" not in curl_blocks.get("customer1-health", "")
    assert "Authorization" not in curl_blocks.get("customer2-health", "")
    assert f"Bearer {SAMPLE_TOKEN}" in curl_blocks.get("httpbin", "")
    assert f"Bearer {SAMPLE_TOKEN}" in curl_blocks.get("customer1-httpbin", "")
    assert f"Bearer {SAMPLE_TOKEN}" in curl_blocks.get("customer2-httpbin", "")


def test_test_page_has_collapse_all_button(authenticated_client):
    response = authenticated_client.get("/test")
    body = response.text
    assert "Collapse all" in body


def test_test_page_has_results_summary(authenticated_client):
    response = authenticated_client.get("/test")
    body = response.text
    assert "results-summary" in body
    assert "passed" in body


def test_test_page_badge_has_id_for_dynamic_update(authenticated_client):
    """Each badge must have id='badge-<label>' so JS can update it after running."""
    response = authenticated_client.get("/test")
    body = response.text
    badge_ids = re.findall(r'id="badge-([^"]+)"', body)
    assert set(badge_ids) == {"httpbin", "customer1-health", "customer2-health", "customer1-httpbin", "customer2-httpbin"}


def test_test_page_has_group_separators(authenticated_client):
    """Page must render group separator rows with Own Tenant and Cross-Tenant labels."""
    response = authenticated_client.get("/test")
    body = response.text
    assert "group-separator" in body
    assert "Own Tenant" in body
    assert "Cross-Tenant" in body


def test_test_page_group_order(authenticated_client):
    """Own Tenant group must appear before Cross-Tenant group in the HTML."""
    response = authenticated_client.get("/test")
    body = response.text
    own_pos = body.index("Own Tenant")
    cross_pos = body.index("Cross-Tenant")
    assert own_pos < cross_pos


def test_test_page_run_buttons_are_client_side(authenticated_client):
    """Run buttons must call runSingle() in JS, not /test/run server endpoint."""
    response = authenticated_client.get("/test")
    body = response.text
    assert "runSingle" in body
    assert "/test/run" not in body


def test_test_run_endpoint_removed(api_client):
    """/test/run endpoint must not exist — tests run client-side."""
    response = api_client.get("/test/run", params={"url": "http://example.com", "expected": 200})
    assert response.status_code == 404


# ── Profile (/profile) ───────────────────────────────────────────────────────

def test_profile_redirects_when_no_session(api_client):
    response = api_client.get("/profile")
    assert response.status_code == 302


def test_profile_shows_all_claims(authenticated_client):
    response = authenticated_client.get("/profile")
    assert response.status_code == 200
    body = response.text
    assert "silvio@example.com" in body
    assert "customer1" in body
    assert "abc123-uuid" in body


# ── Logout (/logout) ─────────────────────────────────────────────────────────

def test_logout_redirects_to_platform_url(authenticated_client):
    response = authenticated_client.get("/logout")
    assert response.status_code == 302
    assert "wasp.silvios.me" in response.headers["location"]


def test_logout_clears_session_cookie(authenticated_client):
    response = authenticated_client.get("/logout")
    set_cookie = response.headers.get("set-cookie", "")
    assert "session=" in set_cookie
    assert "max-age=0" in set_cookie.lower() or 'session=""' in set_cookie
