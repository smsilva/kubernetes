import httpx


class DomainValidationError(Exception):
    pass


class DomainValidator:
    def __init__(self, discovery_url: str):
        self._discovery_url = discovery_url

    def get_tenant_for_domain(self, domain: str) -> str:
        try:
            response = httpx.get(
                f"{self._discovery_url}/tenant",
                params={"domain": domain},
                timeout=5.0,
            )
        except httpx.RequestError as e:
            raise DomainValidationError(f"Discovery service unreachable: {e}") from e

        if response.status_code == 404:
            raise DomainValidationError(f"Domain '{domain}' is not registered")
        if response.status_code != 200:
            raise DomainValidationError(f"Discovery service returned {response.status_code}")

        return response.json()["tenant_id"]
