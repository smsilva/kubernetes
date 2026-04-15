from unittest.mock import MagicMock, patch

from botocore.exceptions import ClientError
from fastapi.testclient import TestClient

from app.repository import DynamoDBTenantRepository
from tests.conftest import CUSTOMER1, CUSTOMER2


def test_get_repository_raises_when_env_vars_are_missing():
    import os
    import pytest
    from app.main import get_repository
    get_repository.cache_clear()

    env_without_aws = {k: v for k, v in os.environ.items() if k not in ("AWS_REGION", "DYNAMODB_TABLE", "BACKEND", "SQLITE_DB_PATH")}
    with patch.dict("os.environ", env_without_aws, clear=True):
        with pytest.raises(KeyError):
            get_repository()

    get_repository.cache_clear()


def test_get_repository_returns_same_instance_on_repeated_calls():
    from app.main import get_repository
    get_repository.cache_clear()

    with patch("app.main.boto3") as mock_boto3, \
         patch.dict("os.environ", {"AWS_REGION": "us-east-1", "DYNAMODB_TABLE": "tenant-registry"}):
        mock_boto3.client.return_value = MagicMock()

        repo1 = get_repository()
        repo2 = get_repository()

        assert repo1 is repo2
        mock_boto3.client.assert_called_once()

    get_repository.cache_clear()


def test_get_repository_returns_dynamodb_repository_using_env_vars():
    from app.main import get_repository
    get_repository.cache_clear()

    with patch("app.main.boto3") as mock_boto3, \
         patch.dict("os.environ", {"AWS_REGION": "us-east-1", "DYNAMODB_TABLE": "tenant-registry"}):
        mock_boto3.client.return_value = MagicMock()

        repository = get_repository()

        assert isinstance(repository, DynamoDBTenantRepository)
        mock_boto3.client.assert_called_once_with("dynamodb", region_name="us-east-1")

    get_repository.cache_clear()


def test_get_repository_returns_sqlite_repository_when_backend_is_sqlite():
    import pytest
    from app.main import get_repository
    from app.repository import SQLiteTenantRepository
    get_repository.cache_clear()

    with patch.dict("os.environ", {"BACKEND": "sqlite", "SQLITE_DB_PATH": ":memory:"}):
        repository = get_repository()
        assert isinstance(repository, SQLiteTenantRepository)

    get_repository.cache_clear()


def test_get_repository_raises_for_unknown_backend():
    import pytest
    from app.main import get_repository
    get_repository.cache_clear()

    with patch.dict("os.environ", {"BACKEND": "redis"}):
        with pytest.raises(ValueError, match="BACKEND"):
            get_repository()

    get_repository.cache_clear()


def test_get_repository_seeds_sqlite_from_file_when_seed_file_is_set(tmp_path):
    import json
    import pytest
    from app.main import get_repository
    from app.repository import SQLiteTenantRepository
    get_repository.cache_clear()

    seed_data = [
        {
            "domain": "customer1.com",
            "tenant_id": "customer1",
            "tenant_url": "http://customer1.wasp.local:32080",
            "client_id": "wasp-platform",
            "idp_name": "",
            "cognito_pool_id": "",
        }
    ]
    seed_file = tmp_path / "seed.json"
    seed_file.write_text(json.dumps(seed_data))

    with patch.dict("os.environ", {"BACKEND": "sqlite", "SQLITE_DB_PATH": ":memory:", "SQLITE_SEED_FILE": str(seed_file)}):
        repo = get_repository()
        tenant = repo.find_by_domain("customer1.com")
        assert tenant is not None
        assert tenant.tenant_id == "customer1"

    get_repository.cache_clear()


def test_get_repository_sqlite_without_seed_file_starts_empty():
    import pytest
    from app.main import get_repository
    from app.repository import SQLiteTenantRepository
    get_repository.cache_clear()

    with patch.dict("os.environ", {"BACKEND": "sqlite", "SQLITE_DB_PATH": ":memory:"}):
        repo = get_repository()
        assert repo.find_by_domain("customer1.com") is None

    get_repository.cache_clear()


def test_get_tenant_returns_200_and_config_for_registered_domain(api_client):
    response = api_client.get("/tenant?domain=gmail.com")

    assert response.status_code == 200
    data = response.json()
    assert data["tenant_id"] == CUSTOMER1.tenant_id
    assert data["tenant_url"] == CUSTOMER1.tenant_url
    assert data["client_id"] == CUSTOMER1.client_id
    assert data["idp_name"] == CUSTOMER1.idp_name
    assert data["cognito_pool_id"] == CUSTOMER1.cognito_pool_id


def test_get_tenant_returns_correct_config_for_second_registered_domain(api_client):
    response = api_client.get("/tenant?domain=customer2.com")

    assert response.status_code == 200
    data = response.json()
    assert data["tenant_id"] == CUSTOMER2.tenant_id
    assert data["idp_name"] == CUSTOMER2.idp_name


def test_get_tenant_returns_404_for_unregistered_domain(api_client):
    response = api_client.get("/tenant?domain=unknown.com")

    assert response.status_code == 404
    assert "unknown.com" in response.json()["detail"]


def test_get_tenant_returns_422_when_domain_param_is_missing(api_client):
    response = api_client.get("/tenant")

    assert response.status_code == 422


def test_health_check_returns_200(api_client):
    response = api_client.get("/health")

    assert response.status_code == 200


def test_get_tenant_returns_404_for_empty_domain(api_client):
    response = api_client.get("/tenant?domain=")

    assert response.status_code == 404


def test_get_tenant_returns_503_with_structured_error_when_dynamodb_raises_client_error():
    from app.main import app, get_repository
    from app.repository import DynamoDBTenantRepository

    broken_repository = MagicMock(spec=DynamoDBTenantRepository)
    broken_repository.find_by_domain.side_effect = ClientError(
        {"Error": {"Code": "ResourceNotFoundException", "Message": "Table not found"}},
        "GetItem",
    )

    app.dependency_overrides[get_repository] = lambda: broken_repository
    client = TestClient(app, raise_server_exceptions=False)

    response = client.get("/tenant?domain=gmail.com")

    app.dependency_overrides.clear()
    assert response.status_code == 503
    body = response.json()
    assert "detail" in body
    assert "DynamoDB" in body["detail"]


def test_get_tenant_returns_503_with_structured_error_when_dynamodb_raises_access_denied():
    from app.main import app, get_repository
    from app.repository import DynamoDBTenantRepository

    broken_repository = MagicMock(spec=DynamoDBTenantRepository)
    broken_repository.find_by_domain.side_effect = ClientError(
        {"Error": {"Code": "AccessDeniedException", "Message": "User is not authorized to perform: dynamodb:GetItem"}},
        "GetItem",
    )

    app.dependency_overrides[get_repository] = lambda: broken_repository
    client = TestClient(app, raise_server_exceptions=False)

    response = client.get("/tenant?domain=gmail.com")

    app.dependency_overrides.clear()
    assert response.status_code == 503
    body = response.json()
    assert "detail" in body
    assert "DynamoDB" in body["detail"]
