from .models import TenantConfig


class InMemoryTenantRepository:
    def __init__(self, tenants: dict[str, TenantConfig] | None = None):
        self._tenants: dict[str, TenantConfig] = tenants or {}

    def find_by_domain(self, domain: str) -> TenantConfig | None:
        return self._tenants.get(domain)
