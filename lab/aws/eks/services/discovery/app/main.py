import os
from functools import lru_cache

import boto3
from fastapi import Depends, FastAPI, HTTPException, Query

from .models import TenantConfig
from .repository import DynamoDBTenantRepository

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
    tenant = repository.find_by_domain(domain)
    if not tenant:
        raise HTTPException(status_code=404, detail=f"Tenant not found for domain: {domain}")
    return tenant
