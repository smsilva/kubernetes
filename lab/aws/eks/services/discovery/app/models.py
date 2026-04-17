from pydantic import BaseModel


class TenantConfig(BaseModel):
    tenant_id: str
    tenant_url: str
    client_id: str
    idp_name: str
    idp_pool_id: str
