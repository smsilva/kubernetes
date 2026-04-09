import json
import os
from functools import lru_cache
from pathlib import Path

from fastapi import Depends, FastAPI, HTTPException, Query

from .models import TenantConfig
from .repository import InMemoryTenantRepository

app = FastAPI(title="Discovery Service", version="1.0.0")

_DATA_FILE = Path(__file__).parent / "data" / "tenants.json"


@lru_cache
def get_repository() -> InMemoryTenantRepository:
    entries = json.loads(_DATA_FILE.read_text())
    tenants = {
        entry["domain"]: TenantConfig(**{k: v for k, v in entry.items() if k != "domain"})
        for entry in entries
    }
    return InMemoryTenantRepository(tenants=tenants)


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/tenant", response_model=TenantConfig)
def get_tenant_by_domain(
    domain: str = Query(..., description="Email domain to look up (e.g. gmail.com)"),
    repository: InMemoryTenantRepository = Depends(get_repository),
):
    tenant = repository.find_by_domain(domain)
    if not tenant:
        raise HTTPException(status_code=404, detail=f"Tenant not found for domain: {domain}")
    return tenant
