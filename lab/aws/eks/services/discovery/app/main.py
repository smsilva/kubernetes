import logging
import os
from functools import lru_cache

import boto3
from botocore.exceptions import ClientError
from fastapi import Depends, FastAPI, HTTPException, Query

from .models import TenantConfig
from .repository import DynamoDBTenantRepository

_log_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO)
logging.basicConfig(level=_log_level)
logging.getLogger().setLevel(_log_level)

app = FastAPI(title="Discovery Service", version="1.0.0")


@lru_cache
def get_repository() -> DynamoDBTenantRepository:
    region = os.environ["AWS_REGION"]
    table_name = os.environ["DYNAMODB_TABLE"]
    client = boto3.client("dynamodb", region_name=region)
    return DynamoDBTenantRepository(client=client, table_name=table_name)


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/tenant", response_model=TenantConfig)
def get_tenant_by_domain(
    domain: str = Query(..., description="Email domain to look up (e.g. gmail.com)"),
    repository: DynamoDBTenantRepository = Depends(get_repository),
):
    try:
        tenant = repository.find_by_domain(domain)
    except ClientError as exc:
        code = exc.response["Error"]["Code"]
        raise HTTPException(
            status_code=503,
            detail=f"DynamoDB error ({code}): service temporarily unavailable",
        ) from exc
    if not tenant:
        raise HTTPException(status_code=404, detail=f"Tenant not found for domain: {domain}")
    return tenant
