from unittest.mock import MagicMock, patch

from botocore.exceptions import ClientError

from app.repository import DynamoDBTenantRepository
from tests.conftest import CUSTOMER1, CUSTOMER2


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
