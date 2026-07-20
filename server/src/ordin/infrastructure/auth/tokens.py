import secrets
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

import jwt
from jwt import InvalidTokenError

from ordin.core.errors import InvalidAuthenticationError
from ordin.core.security import HmacDigester
from ordin.modules.auth.models import AccessClaims


class TokenService:
    def __init__(
        self,
        *,
        jwt_secret: str,
        refresh_token_digester: HmacDigester,
        issuer: str,
        audience: str,
        access_ttl_seconds: int,
        refresh_ttl_seconds: int,
    ) -> None:
        self._jwt_secret = jwt_secret
        self._refresh_token_digester = refresh_token_digester
        self._issuer = issuer
        self._audience = audience
        self._access_ttl = timedelta(seconds=access_ttl_seconds)
        self._refresh_ttl = timedelta(seconds=refresh_ttl_seconds)

    @property
    def refresh_ttl_seconds(self) -> int:
        return int(self._refresh_ttl.total_seconds())

    def issue_access_token(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        now: datetime,
    ) -> tuple[str, datetime]:
        expires_at = now + self._access_ttl
        payload: dict[str, Any] = {
            "sub": str(user_id),
            "sid": str(session_id),
            "iss": self._issuer,
            "aud": self._audience,
            "iat": int(now.timestamp()),
            "exp": int(expires_at.timestamp()),
            "jti": secrets.token_hex(16),
        }
        return jwt.encode(payload, self._jwt_secret, algorithm="HS256"), expires_at

    def decode_access_token(self, encoded_token: str, *, now: datetime) -> AccessClaims:
        try:
            payload = jwt.decode(
                encoded_token,
                self._jwt_secret,
                algorithms=["HS256"],
                audience=self._audience,
                issuer=self._issuer,
                options={
                    "require": ["sub", "sid", "iss", "aud", "iat", "exp", "jti"],
                    "verify_exp": False,
                    "verify_iat": False,
                },
            )
            user_id = UUID(payload["sub"])
            session_id = UUID(payload["sid"])
            expires_at = datetime.fromtimestamp(int(payload["exp"]), tz=UTC)
        except (InvalidTokenError, KeyError, TypeError, ValueError) as error:
            raise InvalidAuthenticationError from error
        if expires_at <= now:
            raise InvalidAuthenticationError
        return AccessClaims(user_id=user_id, session_id=session_id, expires_at=expires_at)

    def generate_refresh_token(self) -> str:
        return secrets.token_urlsafe(48)

    def digest_refresh_token(self, token: str) -> str:
        return self._refresh_token_digester.digest(token)
