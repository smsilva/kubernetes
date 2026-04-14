import json
import logging

import httpx

_logger = logging.getLogger(__name__)


async def fetch_url(url: str, timeout: float = 10.0) -> dict:
    """Fetch a URL and return a normalized result dict.

    Returns:
        {
            "url": str,
            "status_code": int | None,
            "result_json": str | None,   # pretty-printed JSON on 200
            "error": str | None,         # human-readable message on failure
        }
    """
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.get(url)

        if resp.status_code == 200:
            try:
                result_json = json.dumps(resp.json(), indent=2)
            except Exception:
                result_json = None
            return {
                "url": url,
                "status_code": resp.status_code,
                "result_json": result_json,
                "error": None,
            }

        return {
            "url": url,
            "status_code": resp.status_code,
            "result_json": None,
            "error": f"HTTP {resp.status_code} — {resp.text[:500]}",
        }

    except httpx.ConnectError as exc:
        _logger.error("fetch_url connection error (%s): %s", url, exc)
        return {
            "url": url,
            "status_code": None,
            "result_json": None,
            "error": f"Connection failed: {exc}",
        }

    except httpx.TimeoutException as exc:
        _logger.error("fetch_url timeout (%s): %s", url, exc)
        return {
            "url": url,
            "status_code": None,
            "result_json": None,
            "error": f"Request timed out: {exc}",
        }
