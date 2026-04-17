import pytest
from unittest.mock import MagicMock
from botocore.exceptions import ClientError

from app.models import TenantConfig
from app.repository import DynamoDBTenantRepository, InMemoryTenantRepository
from tests.conftest import CUSTOMER1, CUSTOMER2

CUSTOMER1_DYNAMODB_ITEM = {
    "pk":                    {"S": "domain#gmail.com"},
    "tenant_id":             {"S": "customer1"},
    "url":                   {"S": "customer1.wasp.silvios.me"},
    "cognito_app_client_id": {"S": "abc123client"},
    "auth": {"M": {
        "cognito_idp_name":     {"S": "Google"},
        "cognito_user_pool_id": {"S": "us-east-1_ABC123"},
    }},
    "status": {"S": "active"},
}


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


# DynamoDBTenantRepository

def test_dynamodb_repository_returns_tenant_config_when_item_exists():
    dynamodb_client = MagicMock()
    dynamodb_client.get_item.return_value = {"Item": CUSTOMER1_DYNAMODB_ITEM}

    repository = DynamoDBTenantRepository(client=dynamodb_client, table_name="tenant-registry")
    tenant = repository.find_by_domain("gmail.com")

    assert tenant == CUSTOMER1
    dynamodb_client.get_item.assert_called_once_with(
        TableName="tenant-registry",
        Key={"pk": {"S": "domain#gmail.com"}},
    )


def test_dynamodb_repository_returns_none_when_domain_does_not_exist():
    dynamodb_client = MagicMock()
    dynamodb_client.get_item.return_value = {}

    repository = DynamoDBTenantRepository(client=dynamodb_client, table_name="tenant-registry")
    tenant = repository.find_by_domain("unknown.com")

    assert tenant is None


def test_dynamodb_repository_is_case_insensitive_for_domain():
    dynamodb_client = MagicMock()
    dynamodb_client.get_item.return_value = {"Item": CUSTOMER1_DYNAMODB_ITEM}

    repository = DynamoDBTenantRepository(client=dynamodb_client, table_name="tenant-registry")
    tenant = repository.find_by_domain("Gmail.COM")

    assert tenant == CUSTOMER1
    dynamodb_client.get_item.assert_called_once_with(
        TableName="tenant-registry",
        Key={"pk": {"S": "domain#gmail.com"}},
    )


def test_dynamodb_repository_propagates_client_error():
    dynamodb_client = MagicMock()
    dynamodb_client.get_item.side_effect = ClientError(
        {"Error": {"Code": "ResourceNotFoundException", "Message": "Table not found"}},
        "GetItem",
    )

    repository = DynamoDBTenantRepository(client=dynamodb_client, table_name="tenant-registry")

    import pytest
    with pytest.raises(ClientError):
        repository.find_by_domain("gmail.com")


def test_dynamodb_repository_logs_client_error(caplog):
    import logging
    dynamodb_client = MagicMock()
    dynamodb_client.get_item.side_effect = ClientError(
        {"Error": {"Code": "AccessDeniedException", "Message": "User is not authorized"}},
        "GetItem",
    )

    repository = DynamoDBTenantRepository(client=dynamodb_client, table_name="tenant-registry")

    import pytest
    with caplog.at_level(logging.ERROR, logger="app.repository"):
        with pytest.raises(ClientError):
            repository.find_by_domain("gmail.com")

    assert any("AccessDeniedException" in r.message for r in caplog.records)


# SQLiteTenantRepository

from app.repository import SQLiteTenantRepository


@pytest.fixture
def sqlite_repository():
    repo = SQLiteTenantRepository(db_path=":memory:")
    repo.seed([
        {"domain": "gmail.com",      **CUSTOMER1.model_dump()},
        {"domain": "customer2.com",  **CUSTOMER2.model_dump()},
    ])
    return repo


def test_sqlite_repository_returns_none_for_empty_db():
    repo = SQLiteTenantRepository(db_path=":memory:")
    assert repo.find_by_domain("gmail.com") is None


def test_sqlite_repository_find_by_domain_returns_tenant(sqlite_repository):
    tenant = sqlite_repository.find_by_domain("gmail.com")
    assert tenant == CUSTOMER1


def test_sqlite_repository_find_by_domain_returns_none_for_unknown_domain(sqlite_repository):
    assert sqlite_repository.find_by_domain("unknown.com") is None


def test_sqlite_repository_returns_correct_tenant_for_each_domain(sqlite_repository):
    assert sqlite_repository.find_by_domain("gmail.com") == CUSTOMER1
    assert sqlite_repository.find_by_domain("customer2.com") == CUSTOMER2


def test_sqlite_repository_is_case_insensitive(sqlite_repository):
    tenant = sqlite_repository.find_by_domain("Gmail.COM")
    assert tenant == CUSTOMER1


def test_sqlite_repository_returns_all_fields(sqlite_repository):
    tenant = sqlite_repository.find_by_domain("gmail.com")
    assert tenant.tenant_id == CUSTOMER1.tenant_id
    assert tenant.tenant_url == CUSTOMER1.tenant_url
    assert tenant.client_id == CUSTOMER1.client_id
    assert tenant.idp_name == CUSTOMER1.idp_name
    assert tenant.idp_pool_id == CUSTOMER1.idp_pool_id
