import httpx
from pydantic import BaseModel


class TenantInfo(BaseModel):
    tenant_id: str
    tenant_url: str
    client_id: str
    idp_name: str
    idp_pool_id: str


class DiscoveryClient:
    def __init__(self, base_url: str):
        self._base_url = base_url

    def find_tenant_by_domain(self, domain: str) -> TenantInfo | None:
        try:
            response = httpx.get(f"{self._base_url}/tenant", params={"domain": domain})
            if response.status_code == 404:
                return None
            response.raise_for_status()
            return TenantInfo(**response.json())
        except httpx.HTTPError:
            return None
