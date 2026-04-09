from dataclasses import dataclass

import httpx


@dataclass
class CognitoTokens:
    id_token: str
    access_token: str
    refresh_token: str


class CognitoTokenExchangeError(Exception):
    pass


class CognitoClient:
    def __init__(self, domain: str, client_id: str, client_secret: str, callback_url: str):
        self._domain = domain
        self._client_id = client_id
        self._client_secret = client_secret
        self._callback_url = callback_url

    def exchange_code_for_tokens(self, code: str) -> CognitoTokens:
        response = httpx.post(
            f"https://{self._domain}/oauth2/token",
            data={
                "grant_type": "authorization_code",
                "code": code,
                "client_id": self._client_id,
                "redirect_uri": self._callback_url,
            },
            auth=(self._client_id, self._client_secret),
        )
        if response.status_code != 200:
            raise CognitoTokenExchangeError(
                f"Token exchange failed: {response.status_code} {response.text}"
            )
        body = response.json()
        return CognitoTokens(
            id_token=body["id_token"],
            access_token=body["access_token"],
            refresh_token=body.get("refresh_token", ""),
        )
