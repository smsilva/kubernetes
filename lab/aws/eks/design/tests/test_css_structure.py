"""
Structural linter for the shared design system CSS.

Verifies:
- design/shared/tokens.css contains expected custom properties
- design/shared/base.css contains expected component selectors
- Each service CSS starts with @import of shared files
- No service CSS contains a duplicate :root variable block
"""

from pathlib import Path

SHARED = Path(__file__).parent.parent / "shared"
SERVICES_DIR = Path(__file__).parent.parent.parent / "services"

SERVICE_CSS = {
    "platform-frontend": SERVICES_DIR / "platform-frontend/app/static/login.css",
    "callback-handler": SERVICES_DIR / "callback-handler/app/static/error.css",
    "tenant-frontend": SERVICES_DIR / "tenant-frontend/app/static/app.css",
}


def test_tokens_css_exists():
    assert (SHARED / "tokens.css").is_file()


def test_base_css_exists():
    assert (SHARED / "base.css").is_file()


def test_tokens_contains_primary_color():
    content = (SHARED / "tokens.css").read_text()
    assert "--color-primary" in content


def test_tokens_contains_dark_theme_block():
    content = (SHARED / "tokens.css").read_text()
    assert '[data-theme="dark"]' in content


def test_tokens_contains_prefers_color_scheme_block():
    content = (SHARED / "tokens.css").read_text()
    assert "prefers-color-scheme: dark" in content


def test_tokens_contains_error_bg_for_callback_handler():
    content = (SHARED / "tokens.css").read_text()
    assert "--color-error-bg" in content


def test_tokens_contains_error_surface_for_tenant_frontend():
    content = (SHARED / "tokens.css").read_text()
    assert "--color-error-surface" in content


def test_base_contains_theme_toggle():
    content = (SHARED / "base.css").read_text()
    assert ".theme-toggle" in content


def test_base_contains_ripple_keyframe():
    content = (SHARED / "base.css").read_text()
    assert "@keyframes ripple" in content


def test_base_contains_btn_filled():
    content = (SHARED / "base.css").read_text()
    assert ".btn-filled" in content


def test_base_contains_btn_outlined():
    content = (SHARED / "base.css").read_text()
    assert ".btn-outlined" in content


def test_base_contains_logo_section():
    content = (SHARED / "base.css").read_text()
    assert ".logo-section" in content


def test_base_does_not_define_root_variables():
    content = (SHARED / "base.css").read_text()
    assert ":root {" not in content


def test_service_css_imports_tokens(svc, css_path):
    content = css_path.read_text()
    assert "@import './shared/tokens.css'" in content, \
        f"{svc}: login/error/app.css must import shared tokens"


def test_service_css_imports_base(svc, css_path):
    content = css_path.read_text()
    assert "@import './shared/base.css'" in content, \
        f"{svc}: login/error/app.css must import shared base"


def test_service_css_has_no_duplicate_root_block(svc, css_path):
    content = css_path.read_text()
    count = content.count(":root {")
    assert count == 0, \
        f"{svc}: found {count} :root block(s) — variables must live in shared/tokens.css"


import pytest


@pytest.fixture(params=list(SERVICE_CSS.keys()))
def svc(request):
    return request.param


@pytest.fixture
def css_path(svc):
    return SERVICE_CSS[svc]
