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


def test_test_page_shows_json_on_success(authenticated_client, httpx_mock: HTTPXMock):
    httpx_mock.add_response(
        url="http://httpbin-mock:8000/get",
        json=SAMPLE_HTTPBIN_RESPONSE,
        status_code=200,
    )
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "httpbin-mock:8000" in body
    assert "origin" in body


def test_test_page_url_preserves_lowercase(authenticated_client, httpx_mock: HTTPXMock):
    httpx_mock.add_response(
        url="http://httpbin-mock:8000/get",
        json=SAMPLE_HTTPBIN_RESPONSE,
        status_code=200,
    )
    response = authenticated_client.get("/test")
    body = response.text
    # URL must appear as-is, not uppercased by CSS class on the wrapping element
    assert 'text-transform: none' in body or 'url-text' in body


def test_test_page_shows_error_on_httpbin_non_200(authenticated_client, httpx_mock: HTTPXMock):
    httpx_mock.add_response(
        url="http://httpbin-mock:8000/get",
        status_code=503,
        text="Service Unavailable",
    )
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "HTTP 503" in body


def test_test_page_shows_error_on_httpbin_connection_failure(authenticated_client, httpx_mock: HTTPXMock):
    httpx_mock.add_exception(
        httpx.ConnectError("connection refused"),
        url="http://httpbin-mock:8000/get",
    )
    response = authenticated_client.get("/test")
    assert response.status_code == 200
    body = response.text
    assert "error" in body.lower() or "Error" in body


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
