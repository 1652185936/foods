from datetime import datetime
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from ordin.core.identifiers import new_uuid
from ordin.infrastructure.database.models import (
    AuthIdentityRow,
    DeviceRow,
    HealthProfileRow,
    SessionRow,
    UserRow,
)
from ordin.modules.auth.models import (
    AuthenticatedSession,
    DeviceRegistration,
    RefreshRotation,
    RefreshRotationStatus,
)
from ordin.modules.users.models import (
    GoalType,
    HealthProfile,
    HealthProfileInput,
    HealthProfileWriteResult,
    User,
    UserStatus,
    UserWriteResult,
    VersionedWriteStatus,
)


class SqlAlchemyApplicationRepository:
    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def create_authenticated_session(
        self,
        *,
        identity_subject_hash: str,
        device: DeviceRegistration,
        session_id: UUID,
        token_family_id: UUID,
        refresh_token_hash: str,
        refresh_expires_at: datetime,
        now: datetime,
    ) -> tuple[User, AuthenticatedSession]:
        async with self._session_factory() as session, session.begin():
            advisory_key = int.from_bytes(
                bytes.fromhex(identity_subject_hash)[:8],
                byteorder="big",
                signed=True,
            )
            await session.execute(select(func.pg_advisory_xact_lock(advisory_key)))
            identity = await session.scalar(
                select(AuthIdentityRow).where(
                    AuthIdentityRow.provider == "phone",
                    AuthIdentityRow.subject_hash == identity_subject_hash,
                )
            )
            if identity is None:
                user_row = UserRow(
                    id=new_uuid(),
                    nickname=None,
                    status=UserStatus.ACTIVE.value,
                    version=1,
                    created_at=now,
                    updated_at=now,
                )
                session.add(user_row)
                await session.flush()
                session.add(
                    AuthIdentityRow(
                        id=new_uuid(),
                        user_id=user_row.id,
                        provider="phone",
                        subject_hash=identity_subject_hash,
                        created_at=now,
                    )
                )
                await session.flush()
            else:
                existing_user = await session.get(UserRow, identity.user_id)
                if existing_user is None or existing_user.status != UserStatus.ACTIVE.value:
                    raise RuntimeError("active identity references a missing or inactive user")
                user_row = existing_user

            device_row = await session.scalar(
                select(DeviceRow).where(
                    DeviceRow.user_id == user_row.id,
                    DeviceRow.installation_id == device.installation_id,
                )
            )
            if device_row is None:
                device_row = DeviceRow(
                    id=new_uuid(),
                    user_id=user_row.id,
                    installation_id=device.installation_id,
                    platform=device.platform.value,
                    app_version=device.app_version,
                    created_at=now,
                    last_seen_at=now,
                )
                session.add(device_row)
            else:
                device_row.platform = device.platform.value
                device_row.app_version = device.app_version
                device_row.last_seen_at = now

            session.add(
                SessionRow(
                    id=session_id,
                    user_id=user_row.id,
                    device_id=device_row.id,
                    token_family_id=token_family_id,
                    refresh_token_hash=refresh_token_hash,
                    expires_at=refresh_expires_at,
                    revoked_at=None,
                    revoked_reason=None,
                    replaced_by_session_id=None,
                    created_at=now,
                    last_seen_at=now,
                )
            )
            await session.flush()
            return self._to_user(user_row), AuthenticatedSession(
                user_id=user_row.id,
                session_id=session_id,
                refresh_expires_at=refresh_expires_at,
            )

    async def rotate_refresh_session(
        self,
        *,
        current_refresh_token_hash: str,
        device_installation_id: UUID,
        new_session_id: UUID,
        new_refresh_token_hash: str,
        new_refresh_expires_at: datetime,
        now: datetime,
    ) -> RefreshRotation:
        async with self._session_factory() as session, session.begin():
            current = await session.scalar(
                select(SessionRow)
                .where(SessionRow.refresh_token_hash == current_refresh_token_hash)
                .with_for_update()
            )
            if current is None:
                return RefreshRotation(RefreshRotationStatus.INVALID)

            device = await session.get(DeviceRow, current.device_id)
            if device is None or device.installation_id != device_installation_id:
                return RefreshRotation(RefreshRotationStatus.INVALID)

            if current.revoked_at is not None or current.replaced_by_session_id is not None:
                await session.execute(
                    update(SessionRow)
                    .where(
                        SessionRow.token_family_id == current.token_family_id,
                        SessionRow.revoked_at.is_(None),
                    )
                    .values(revoked_at=now, revoked_reason="token_reuse")
                )
                return RefreshRotation(RefreshRotationStatus.REUSED)

            if current.expires_at <= now:
                current.revoked_at = now
                current.revoked_reason = "expired"
                return RefreshRotation(RefreshRotationStatus.INVALID)

            user_row = await session.get(UserRow, current.user_id)
            if user_row is None or user_row.status != UserStatus.ACTIVE.value:
                current.revoked_at = now
                current.revoked_reason = "user_inactive"
                return RefreshRotation(RefreshRotationStatus.INVALID)

            replacement = SessionRow(
                id=new_session_id,
                user_id=current.user_id,
                device_id=current.device_id,
                token_family_id=current.token_family_id,
                refresh_token_hash=new_refresh_token_hash,
                expires_at=new_refresh_expires_at,
                revoked_at=None,
                revoked_reason=None,
                replaced_by_session_id=None,
                created_at=now,
                last_seen_at=now,
            )
            session.add(replacement)
            await session.flush()
            current.revoked_at = now
            current.revoked_reason = "rotated"
            current.replaced_by_session_id = replacement.id
            current.last_seen_at = now
            return RefreshRotation(
                RefreshRotationStatus.ROTATED,
                AuthenticatedSession(
                    user_id=current.user_id,
                    session_id=new_session_id,
                    refresh_expires_at=new_refresh_expires_at,
                ),
            )

    async def revoke_session(self, *, user_id: UUID, session_id: UUID, now: datetime) -> None:
        async with self._session_factory() as session, session.begin():
            current = await session.scalar(
                select(SessionRow)
                .where(SessionRow.id == session_id, SessionRow.user_id == user_id)
                .with_for_update()
            )
            if current is not None and current.revoked_at is None:
                current.revoked_at = now
                current.revoked_reason = "logout"

    async def get_authenticated_user(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        now: datetime,
    ) -> User | None:
        async with self._session_factory() as session:
            row = await session.scalar(
                select(UserRow)
                .join(SessionRow, SessionRow.user_id == UserRow.id)
                .where(
                    UserRow.id == user_id,
                    UserRow.status == UserStatus.ACTIVE.value,
                    SessionRow.id == session_id,
                    SessionRow.revoked_at.is_(None),
                    SessionRow.expires_at > now,
                )
            )
            return self._to_user(row) if row is not None else None

    async def get_user(self, user_id: UUID) -> User | None:
        async with self._session_factory() as session:
            row = await session.scalar(
                select(UserRow).where(
                    UserRow.id == user_id,
                    UserRow.status == UserStatus.ACTIVE.value,
                )
            )
            return self._to_user(row) if row is not None else None

    async def update_user_nickname(
        self,
        *,
        user_id: UUID,
        expected_version: int,
        nickname: str,
        now: datetime,
    ) -> UserWriteResult:
        async with self._session_factory() as session, session.begin():
            row = await session.scalar(
                select(UserRow).where(UserRow.id == user_id).with_for_update()
            )
            if row is None or row.status != UserStatus.ACTIVE.value:
                return UserWriteResult(VersionedWriteStatus.NOT_FOUND)
            if row.version != expected_version:
                return UserWriteResult(VersionedWriteStatus.CONFLICT)
            row.nickname = nickname
            row.version += 1
            row.updated_at = now
            await session.flush()
            return UserWriteResult(VersionedWriteStatus.UPDATED, self._to_user(row))

    async def get_health_profile(self, user_id: UUID) -> HealthProfile | None:
        async with self._session_factory() as session:
            row = await session.get(HealthProfileRow, user_id)
            return self._to_health_profile(row) if row is not None else None

    async def put_health_profile(
        self,
        *,
        user_id: UUID,
        expected_version: int,
        profile: HealthProfileInput,
        now: datetime,
    ) -> HealthProfileWriteResult:
        async with self._session_factory() as session, session.begin():
            user_row = await session.scalar(
                select(UserRow).where(UserRow.id == user_id).with_for_update()
            )
            if user_row is None or user_row.status != UserStatus.ACTIVE.value:
                return HealthProfileWriteResult(VersionedWriteStatus.NOT_FOUND)
            row = await session.scalar(
                select(HealthProfileRow)
                .where(HealthProfileRow.user_id == user_id)
                .with_for_update()
            )
            current_version = row.version if row is not None else 0
            if current_version != expected_version:
                return HealthProfileWriteResult(VersionedWriteStatus.CONFLICT)
            if row is None:
                row = HealthProfileRow(
                    user_id=user_id,
                    birth_date=profile.birth_date,
                    height_cm=profile.height_cm,
                    current_weight_kg=profile.current_weight_kg,
                    target_weight_kg=profile.target_weight_kg,
                    goal_type=profile.goal_type.value if profile.goal_type else None,
                    daily_energy_target_kcal=None,
                    version=1,
                    created_at=now,
                    updated_at=now,
                )
                session.add(row)
            else:
                row.birth_date = profile.birth_date
                row.height_cm = profile.height_cm
                row.current_weight_kg = profile.current_weight_kg
                row.target_weight_kg = profile.target_weight_kg
                row.goal_type = profile.goal_type.value if profile.goal_type else None
                row.version += 1
                row.updated_at = now
            await session.flush()
            return HealthProfileWriteResult(
                VersionedWriteStatus.UPDATED,
                self._to_health_profile(row),
            )

    async def ping(self) -> None:
        async with self._session_factory() as session:
            await session.execute(select(1))

    @staticmethod
    def _to_user(row: UserRow) -> User:
        return User(
            id=row.id,
            nickname=row.nickname,
            status=UserStatus(row.status),
            version=row.version,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )

    @staticmethod
    def _to_health_profile(row: HealthProfileRow) -> HealthProfile:
        return HealthProfile(
            user_id=row.user_id,
            birth_date=row.birth_date,
            height_cm=row.height_cm,
            current_weight_kg=row.current_weight_kg,
            target_weight_kg=row.target_weight_kg,
            goal_type=GoalType(row.goal_type) if row.goal_type is not None else None,
            daily_energy_target_kcal=row.daily_energy_target_kcal,
            version=row.version,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )
