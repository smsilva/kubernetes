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


def _mock_all_test_urls(httpx_mock: HTTPXMock, *, httpbin_status=200, c1_status=200, c2_status=403):
    """Register mock response only for httpbin — customer URLs are now fetched client-side."""
    if httpbin_status == 200:
        httpx_mock.add_response(url="http://httpbin-mock:8000/get", json=SAMPLE_HTTPBIN_RESPONSE, status_code=200)
    else:
        httpx_mock.add_response(url="http://httpbin-mock:8000/get", status_code=httpbin_status, text="error")


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
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "connection" in body.lower()


def test_test_page_shows_three_test_results(authenticated_client, httpx_mock: HTTPXMock):
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "httpbin-mock:8000" in body
    assert "customer1-mock" in body
    assert "customer2-mock" in body


def test_test_page_shows_expected_outcome_per_test(authenticated_client, httpx_mock: HTTPXMock):
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    # httpbin test expects 200; cross-tenant tests expect 403
    assert "200" in body
    assert "403" in body


def test_test_page_has_accordion_structure(authenticated_client, httpx_mock: HTTPXMock):
    _mock_all_test_urls(httpx_mock)
    response = authenticated_client.get("/test")
    body = response.text
    # Each test card has a clickable header and a collapsible body
    assert "accordion-header" in body
    assert "accordion-body" in body


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
