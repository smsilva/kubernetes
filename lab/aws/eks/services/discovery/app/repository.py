import logging
import sqlite3

from botocore.exceptions import ClientError

from .models import TenantConfig

_logger = logging.getLogger(__name__)


class InMemoryTenantRepository:
    def __init__(self, tenants: dict[str, TenantConfig] | None = None):
        self._tenants: dict[str, TenantConfig] = tenants or {}

    def find_by_domain(self, domain: str) -> TenantConfig | None:
        return self._tenants.get(domain)


class SQLiteTenantRepository:
    def __init__(self, db_path: str = "/data/tenants.db"):
        self._db_path = db_path
        self._conn = sqlite3.connect(db_path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._create_table()

    def _create_table(self) -> None:
        self._conn.execute("""
            CREATE TABLE IF NOT EXISTS tenants (
                domain          TEXT PRIMARY KEY,
                tenant_id       TEXT NOT NULL,
                tenant_url      TEXT NOT NULL,
                client_id       TEXT NOT NULL,
                idp_name        TEXT NOT NULL,
                cognito_pool_id TEXT NOT NULL
            )
        """)
        self._conn.commit()

    def seed(self, records: list[dict]) -> None:
        self._conn.executemany(
            """
            INSERT OR REPLACE INTO tenants
                (domain, tenant_id, tenant_url, client_id, idp_name, cognito_pool_id)
            VALUES
                (:domain, :tenant_id, :tenant_url, :client_id, :idp_name, :cognito_pool_id)
            """,
            records,
        )
        self._conn.commit()

    def find_by_domain(self, domain: str) -> TenantConfig | None:
        row = self._conn.execute(
            "SELECT * FROM tenants WHERE domain = ?",
            (domain.lower(),),
        ).fetchone()
        if not row:
            return None
        return TenantConfig(
            tenant_id=row["tenant_id"],
            tenant_url=row["tenant_url"],
            client_id=row["client_id"],
            idp_name=row["idp_name"],
            cognito_pool_id=row["cognito_pool_id"],
        )


class DynamoDBTenantRepository:
    def __init__(self, client, table_name: str):
        self._client = client
        self._table_name = table_name

    def find_by_domain(self, domain: str) -> TenantConfig | None:
        try:
            response = self._client.get_item(
                TableName=self._table_name,
                Key={"pk": {"S": f"domain#{domain.lower()}"}},
            )
        except ClientError as exc:
            _logger.error(
                "DynamoDB ClientError on GetItem table=%s domain=%s code=%s message=%s",
                self._table_name,
                domain,
                exc.response["Error"]["Code"],
                exc.response["Error"]["Message"],
            )
            raise
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
