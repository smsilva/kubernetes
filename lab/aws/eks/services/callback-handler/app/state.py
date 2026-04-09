from dataclasses import dataclass

import jwt


@dataclass
class LoginState:
    tenant_id: str
    return_url: str
    nonce: str


class InvalidStateError(Exception):
    pass


def decode_state_token(token: str, secret: str) -> LoginState:
    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])
        return LoginState(
            tenant_id=payload["tenant_id"],
            return_url=payload["return_url"],
            nonce=payload["nonce"],
        )
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError, KeyError) as e:
        raise InvalidStateError(f"Invalid or expired state token: {e}") from e
