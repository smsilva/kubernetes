import pytest
from fastapi.testclient import TestClient

from app.main import app, get_repository
from app.models import TenantConfig
from app.repository import InMemoryTenantRepository

CUSTOMER1 = TenantConfig(
    tenant_id="customer1",
    tenant_url="customer1.wasp.silvios.me",
    client_id="abc123client",
    idp_name="Google",
    idp_pool_id="us-east-1_ABC123",
)

CUSTOMER2 = TenantConfig(
    tenant_id="customer2",
    tenant_url="customer2.wasp.silvios.me",
    client_id="def456client",
    idp_name="MicrosoftAD-Customer2",
    idp_pool_id="us-east-1_DEF456",
)


@pytest.fixture
def repository_with_two_tenants():
    return InMemoryTenantRepository(tenants={
        "gmail.com": CUSTOMER1,
        "customer2.com": CUSTOMER2,
    })


@pytest.fixture
def api_client(repository_with_two_tenants):
    app.dependency_overrides[get_repository] = lambda: repository_with_two_tenants
    yield TestClient(app)
    app.dependency_overrides.clear()
