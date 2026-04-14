import pytest
from fastapi.testclient import TestClient

from app.discovery_client import TenantInfo
from app.main import app, get_discovery_client

CUSTOMER1_TENANT = TenantInfo(
    tenant_id="customer1",
    tenant_url="customer1.wasp.silvios.me",
    client_id="abc123client",
    idp_name="Google",
    cognito_pool_id="us-east-1_ABC123",
)


class MockDiscoveryClient:
    def __init__(self, tenant_info: TenantInfo | None = None):
        self._tenant_info = tenant_info

    def find_tenant_by_domain(self, domain: str) -> TenantInfo | None:
        return self._tenant_info


@pytest.fixture(autouse=True)
def set_env_vars(monkeypatch):
    monkeypatch.setenv("COGNITO_DOMAIN", "auth.wasp.silvios.me")
    monkeypatch.setenv("CALLBACK_URL", "https://auth.wasp.silvios.me/callback")
    monkeypatch.setenv("STATE_JWT_SECRET", "test-secret-key-long-enough-for-hs256")


@pytest.fixture
def mock_discovery_with_customer1():
    client = MockDiscoveryClient(tenant_info=CUSTOMER1_TENANT)
    app.dependency_overrides[get_discovery_client] = lambda: client
    yield client
    app.dependency_overrides.clear()


@pytest.fixture
def mock_discovery_returns_none():
    client = MockDiscoveryClient(tenant_info=None)
    app.dependency_overrides[get_discovery_client] = lambda: client
    yield client
    app.dependency_overrides.clear()


@pytest.fixture
def api_client():
    return TestClient(app, follow_redirects=False)
