import json
import pytest
import httpx
from pytest_httpx import HTTPXMock

from tests.conftest import SAMPLE_TOKEN, SAMPLE_HTTPBIN_RESPONSE


# ── Health ──────────────────────────────────────────────────────────────────

def test_health_check_returns_200(api_client):
    response = api_client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


# ── Home (/  ) ──────────────────────────────────────────────────────────────

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


def _mock_all_test_urls(
    httpx_mock: HTTPXMock,
    *,
    httpbin_status=200,
    c1_health_status=200,
    c2_health_status=200,
    c1_httpbin_status=200,
    c2_httpbin_status=403,
):
    """Register mock responses for all 5 URLs fetched server-side by /test."""
    if httpbin_status == 200:
        httpx_mock.add_response(url="http://httpbin-mock:8000/get", json=SAMPLE_HTTPBIN_RESPONSE, status_code=200)
    else:
        httpx_mock.add_response(url="http://httpbin-mock:8000/get", status_code=httpbin_status, text="error")
    httpx_mock.add_response(url="https://customer1-mock.wasp.silvios.me/health", status_code=c1_health_status, text="ok")
    httpx_mock.add_response(url="https://customer2-mock.wasp.silvios.me/health", status_code=c2_health_status, text="ok")
    httpx_mock.add_response(url="https://customer1-mock.wasp.silvios.me/httpbin/get", json=SAMPLE_HTTPBIN_RESPONSE, status_code=c1_httpbin_status)
    httpx_mock.add_response(url="https://customer2-mock.wasp.silvios.me/httpbin/get", status_code=c2_httpbin_status, text="RBAC: access denied")


def test_test_page_shows_json_on_success(authenticated_client, httpx_mock: HTTPXMock):
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "httpbin-mock:8000" in body
    assert "origin" in body


def test_test_page_url_preserves_lowercase(authenticated_client, httpx_mock: HTTPXMock):
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    assert 'text-transform: none' in body or 'url-text' in body


def test_test_page_shows_error_on_httpbin_non_200(authenticated_client, httpx_mock: HTTPXMock):
    _mock_all_test_urls(httpx_mock, httpbin_status=503)
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "HTTP 503" in body


def test_test_page_shows_error_on_httpbin_connection_failure(authenticated_client, httpx_mock: HTTPXMock):
    httpx_mock.add_exception(httpx.ConnectError("connection refused"), url="http://httpbin-mock:8000/get")
    httpx_mock.add_response(url="https://customer1-mock.wasp.silvios.me/health", status_code=200, text="ok")
    httpx_mock.add_response(url="https://customer2-mock.wasp.silvios.me/health", status_code=200, text="ok")
    httpx_mock.add_response(url="https://customer1-mock.wasp.silvios.me/httpbin/get", status_code=200, json=SAMPLE_HTTPBIN_RESPONSE)
    httpx_mock.add_response(url="https://customer2-mock.wasp.silvios.me/httpbin/get", status_code=403, text="RBAC: access denied")
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "connection" in body.lower()


def test_test_page_shows_five_test_results(authenticated_client, httpx_mock: HTTPXMock):
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "httpbin-mock:8000" in body
    assert "customer1-mock.wasp.silvios.me/health" in body
    assert "customer2-mock.wasp.silvios.me/health" in body
    assert "customer1-mock.wasp.silvios.me/httpbin/get" in body
    assert "customer2-mock.wasp.silvios.me/httpbin/get" in body


def test_health_tests_always_expect_200(authenticated_client, httpx_mock: HTTPXMock):
    """Health endpoints are open — expected is always 200 regardless of tenant."""
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    # Both health tests should show badge-ok (200) — not badge-deny (403)
    assert body.count("badge-ok") >= 3  # httpbin + c1-health + c2-health


def test_test_page_shows_expected_outcome_per_test(authenticated_client, httpx_mock: HTTPXMock):
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    # httpbin and health tests expect 200; customer2-httpbin expects 403 for customer1 user
    assert "200" in body
    assert "403" in body


def test_test_page_has_accordion_structure(authenticated_client, httpx_mock: HTTPXMock):
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    assert "accordion-header" in body
    assert "accordion-body" in body


def test_test_page_includes_curl_commands(authenticated_client, httpx_mock: HTTPXMock):
    """Each test entry must include a curl_cmd with the JWT Bearer token."""
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "curl" in body
    assert f"Bearer {SAMPLE_TOKEN}" in body


def test_curl_command_uses_curl_i(authenticated_client, httpx_mock: HTTPXMock):
    """curl commands must use -i (show headers+body) not -s -o /dev/null."""
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    assert "curl -i" in body
    assert "curl -s" not in body


def test_health_test_curl_commands_omit_jwt(authenticated_client, httpx_mock: HTTPXMock):
    """Health endpoints are open — their curl commands must not carry a JWT."""
    import re
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    # Extract the text inside each <pre id="curl-*"> block
    curl_blocks = dict(re.findall(r'<pre class="curl-code" id="curl-([^"]+)">([^<]+)</pre>', body))
    assert "Authorization" not in curl_blocks.get("customer1-health", "")
    assert "Authorization" not in curl_blocks.get("customer2-health", "")
    assert f"Bearer {SAMPLE_TOKEN}" in curl_blocks.get("httpbin", "")
    assert f"Bearer {SAMPLE_TOKEN}" in curl_blocks.get("customer1-httpbin", "")
    assert f"Bearer {SAMPLE_TOKEN}" in curl_blocks.get("customer2-httpbin", "")


def test_test_page_has_collapse_all_button(authenticated_client, httpx_mock: HTTPXMock):
    """Test page must have a Collapse all button next to Run all."""
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    assert "Collapse all" in body


def test_test_page_has_results_summary(authenticated_client, httpx_mock: HTTPXMock):
    """Page must include a results summary section."""
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    assert "results-summary" in body
    assert "passed" in body


def test_test_page_badge_has_id_for_dynamic_update(authenticated_client, httpx_mock: HTTPXMock):
    """Each badge must have id='badge-<label>' so JS can update it after running."""
    import re
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    badge_ids = re.findall(r'id="badge-([^"]+)"', body)
    assert set(badge_ids) == {"httpbin", "customer1-health", "customer2-health", "customer1-httpbin", "customer2-httpbin"}


def test_test_page_has_group_separators(authenticated_client, httpx_mock: HTTPXMock):
    """Page must render group separator rows with Own Tenant and Cross-Tenant labels."""
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    assert "group-separator" in body
    assert "Own Tenant" in body
    assert "Cross-Tenant" in body


def test_test_page_group_order(authenticated_client, httpx_mock: HTTPXMock):
    """Own Tenant group must appear before Cross-Tenant group in the HTML."""
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    own_pos = body.index("Own Tenant")
    cross_pos = body.index("Cross-Tenant")
    assert own_pos < cross_pos


def test_httpbin_fetch_passes_jwt(authenticated_client, httpx_mock: HTTPXMock):
    """httpbin fetch must include Authorization: Bearer (Istio sidecar requires JWT)."""
    received_headers = {}

    def capture(request: httpx.Request) -> httpx.Response:
        received_headers.update(dict(request.headers))
        return httpx.Response(200, json=SAMPLE_HTTPBIN_RESPONSE)

    httpx_mock.add_callback(capture, url="http://httpbin-mock:8000/get")
    httpx_mock.add_response(url="https://customer1-mock.wasp.silvios.me/health", status_code=200, text="ok")
    httpx_mock.add_response(url="https://customer2-mock.wasp.silvios.me/health", status_code=200, text="ok")
    httpx_mock.add_response(url="https://customer1-mock.wasp.silvios.me/httpbin/get", json=SAMPLE_HTTPBIN_RESPONSE, status_code=200)
    httpx_mock.add_response(url="https://customer2-mock.wasp.silvios.me/httpbin/get", status_code=403, text="denied")

    response = authenticated_client.get("/test")
    assert response.status_code == 200
    assert received_headers.get("authorization") == f"Bearer {SAMPLE_TOKEN}"


def test_test_run_forwards_jwt_as_bearer(authenticated_client, httpx_mock: HTTPXMock):
    """GET /test/run must forward the session cookie as Authorization: Bearer to the target URL."""
    received_headers = {}

    def capture_request(request: httpx.Request) -> httpx.Response:
        received_headers.update(dict(request.headers))
        return httpx.Response(200, json={"url": str(request.url), "origin": "10.0.0.1"})

    httpx_mock.add_callback(capture_request, url="https://customer1-mock.wasp.silvios.me/httpbin/get")

    response = authenticated_client.get(
        "/test/run",
        params={"url": "https://customer1-mock.wasp.silvios.me/httpbin/get", "expected": 200},
    )
    assert response.status_code == 200
    assert received_headers.get("authorization") == f"Bearer {SAMPLE_TOKEN}"


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
    # Cookie cleared: max-age=0 or expires in the past
    assert "max-age=0" in set_cookie.lower() or 'session=""' in set_cookie
