import httpx
import pytest
from pytest_httpx import HTTPXMock

from app.http import fetch_url

TARGET_URL = "https://httpbin.example.com/get"

SAMPLE_JSON = {"origin": "1.2.3.4", "url": TARGET_URL}


@pytest.mark.anyio
async def test_fetch_url_returns_result_json_on_200(httpx_mock: HTTPXMock):
    httpx_mock.add_response(url=TARGET_URL, json=SAMPLE_JSON, status_code=200)

    result = await fetch_url(TARGET_URL)

    assert result["url"] == TARGET_URL
    assert result["status_code"] == 200
    assert result["error"] is None
    assert '"origin"' in result["result_json"]


@pytest.mark.anyio
async def test_fetch_url_returns_error_on_non_200(httpx_mock: HTTPXMock):
    httpx_mock.add_response(url=TARGET_URL, status_code=403, text="RBAC: access denied")

    result = await fetch_url(TARGET_URL)

    assert result["url"] == TARGET_URL
    assert result["status_code"] == 403
    assert result["result_json"] is None
    assert "403" in result["error"] or "RBAC" in result["error"]


@pytest.mark.anyio
async def test_fetch_url_returns_error_on_connection_failure(httpx_mock: HTTPXMock):
    httpx_mock.add_exception(httpx.ConnectError("connection refused"), url=TARGET_URL)

    result = await fetch_url(TARGET_URL)

    assert result["url"] == TARGET_URL
    assert result["status_code"] is None
    assert result["result_json"] is None
    assert "connection" in result["error"].lower()


@pytest.mark.anyio
async def test_fetch_url_returns_error_on_timeout(httpx_mock: HTTPXMock):
    httpx_mock.add_exception(httpx.TimeoutException("timed out"), url=TARGET_URL)

    result = await fetch_url(TARGET_URL)

    assert result["url"] == TARGET_URL
    assert result["status_code"] is None
    assert result["result_json"] is None
    assert "timed out" in result["error"].lower() or "timeout" in result["error"].lower()
