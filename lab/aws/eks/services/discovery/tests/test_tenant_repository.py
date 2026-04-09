from app.models import TenantConfig
from app.repository import InMemoryTenantRepository
from tests.conftest import CUSTOMER1, CUSTOMER2


def test_empty_repository_returns_none_for_any_domain():
    repository = InMemoryTenantRepository()

    assert repository.find_by_domain("gmail.com") is None


def test_find_by_domain_returns_tenant_when_domain_is_registered(repository_with_two_tenants):
    tenant = repository_with_two_tenants.find_by_domain("gmail.com")

    assert tenant == CUSTOMER1


def test_find_by_domain_returns_none_when_domain_is_not_registered(repository_with_two_tenants):
    tenant = repository_with_two_tenants.find_by_domain("unknown.com")

    assert tenant is None


def test_find_by_domain_returns_correct_tenant_for_each_registered_domain(repository_with_two_tenants):
    assert repository_with_two_tenants.find_by_domain("gmail.com") == CUSTOMER1
    assert repository_with_two_tenants.find_by_domain("customer2.com") == CUSTOMER2
