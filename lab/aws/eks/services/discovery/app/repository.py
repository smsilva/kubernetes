from .models import TenantConfig


class InMemoryTenantRepository:
    def __init__(self, tenants: dict[str, TenantConfig] | None = None):
        self._tenants: dict[str, TenantConfig] = tenants or {}

    def find_by_domain(self, domain: str) -> TenantConfig | None:
        return self._tenants.get(domain)


class DynamoDBTenantRepository:
    def __init__(self, client, table_name: str):
        self._client = client
        self._table_name = table_name

    def find_by_domain(self, domain: str) -> TenantConfig | None:
        response = self._client.get_item(
            TableName=self._table_name,
            Key={"pk": {"S": f"domain#{domain.lower()}"}},
        )
        item = response.get("Item")
        if not item:
            return None
        return TenantConfig(
            tenant_id=item["tenant_id"]["S"],
            tenant_url=item["url"]["S"],
            client_id=item["cognito_app_client_id"]["S"],
            idp_name=item["auth"]["M"]["cognito_idp_name"]["S"],
            cognito_pool_id=item["auth"]["M"]["cognito_user_pool_id"]["S"],
        )
