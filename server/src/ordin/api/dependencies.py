from dataclasses import dataclass
from typing import Annotated
from uuid import UUID

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from ordin.core.errors import InvalidAuthenticationError
from ordin.infrastructure.container import AppContainer
from ordin.modules.users.models import User

bearer_scheme = HTTPBearer(auto_error=False, scheme_name="AccessToken")


@dataclass(frozen=True, slots=True)
class Principal:
    user: User
    session_id: UUID


def get_container(request: Request) -> AppContainer:
    container = getattr(request.app.state, "container", None)
    if not isinstance(container, AppContainer):
        raise RuntimeError("application container is not initialized")
    return container


async def get_principal(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    container: Annotated[AppContainer, Depends(get_container)],
) -> Principal:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise InvalidAuthenticationError
    claims = container.token_service.decode_access_token(
        credentials.credentials,
        now=container.clock.now(),
    )
    user = await container.repository.get_authenticated_user(
        user_id=claims.user_id,
        session_id=claims.session_id,
        now=container.clock.now(),
    )
    if user is None:
        raise InvalidAuthenticationError
    return Principal(user=user, session_id=claims.session_id)


ContainerDependency = Annotated[AppContainer, Depends(get_container)]
PrincipalDependency = Annotated[Principal, Depends(get_principal)]
