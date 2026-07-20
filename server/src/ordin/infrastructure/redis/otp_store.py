from collections.abc import Awaitable
from datetime import UTC, datetime
from typing import cast
from uuid import UUID

from redis.asyncio import Redis

from ordin.modules.auth.models import (
    OtpChallenge,
    OtpVerification,
    OtpVerificationStatus,
)

_CREATE_CHALLENGE = """
local use_idempotency = ARGV[1]
if use_idempotency == '1' then
  local existing = redis.call('GET', KEYS[2])
  if existing then
    local existing_key = ARGV[10] .. existing
    if redis.call('EXISTS', existing_key) == 1 then
      return {existing, '0'}
    end
    redis.call('DEL', KEYS[2])
  end
end
redis.call('HSET', KEYS[1],
  'id', ARGV[2],
  'identity_subject_hash', ARGV[3],
  'digest', ARGV[4],
  'created_at', ARGV[5],
  'expires_at', ARGV[6],
  'max_attempts', ARGV[7],
  'attempts', '0',
  'idempotency_key', KEYS[2])
redis.call('EXPIRE', KEYS[1], ARGV[8])
if use_idempotency == '1' then
  redis.call('SET', KEYS[2], ARGV[2], 'EX', ARGV[9])
end
return {ARGV[2], '1'}
"""

_VERIFY_CHALLENGE = """
if redis.call('EXISTS', KEYS[1]) == 0 then
  return {'invalid', ''}
end
local expires_at = tonumber(redis.call('HGET', KEYS[1], 'expires_at'))
if expires_at <= tonumber(ARGV[2]) then
  local idem = redis.call('HGET', KEYS[1], 'idempotency_key')
  redis.call('DEL', KEYS[1])
  if idem and idem ~= '' then redis.call('DEL', idem) end
  return {'expired', ''}
end
local attempts = tonumber(redis.call('HGET', KEYS[1], 'attempts'))
local max_attempts = tonumber(redis.call('HGET', KEYS[1], 'max_attempts'))
if attempts >= max_attempts then
  local idem = redis.call('HGET', KEYS[1], 'idempotency_key')
  redis.call('DEL', KEYS[1])
  if idem and idem ~= '' then redis.call('DEL', idem) end
  return {'attempts_exhausted', ''}
end
local digest = redis.call('HGET', KEYS[1], 'digest')
if digest ~= ARGV[1] then
  attempts = redis.call('HINCRBY', KEYS[1], 'attempts', 1)
  if attempts >= max_attempts then
    local idem = redis.call('HGET', KEYS[1], 'idempotency_key')
    redis.call('DEL', KEYS[1])
    if idem and idem ~= '' then redis.call('DEL', idem) end
    return {'attempts_exhausted', ''}
  end
  return {'invalid', ''}
end
local identity_subject_hash = redis.call('HGET', KEYS[1], 'identity_subject_hash')
local idem = redis.call('HGET', KEYS[1], 'idempotency_key')
redis.call('DEL', KEYS[1])
if idem and idem ~= '' then redis.call('DEL', idem) end
return {'verified', identity_subject_hash}
"""


class RedisOtpChallengeStore:
    def __init__(self, redis: Redis) -> None:
        self._redis = redis
        self._challenge_prefix = "ordin:otp:challenge:"
        self._idempotency_prefix = "ordin:otp:idempotency:"

    async def find_idempotent(
        self,
        key_digest: str,
        now: datetime,
    ) -> OtpChallenge | None:
        idempotency_key = self._idempotency_key(key_digest)
        challenge_id = await cast(
            Awaitable[str | None],
            self._redis.get(idempotency_key),
        )
        if not isinstance(challenge_id, str):
            return None
        challenge = await self._load(UUID(challenge_id))
        if challenge is None or challenge.expires_at <= now:
            await cast(Awaitable[int], self._redis.delete(idempotency_key))
            return None
        return challenge

    async def create(
        self,
        challenge: OtpChallenge,
        idempotency_key_digest: str | None,
    ) -> tuple[OtpChallenge, bool]:
        challenge_key = self._challenge_key(challenge.id)
        idempotency_key = (
            self._idempotency_key(idempotency_key_digest)
            if idempotency_key_digest is not None
            else ""
        )
        ttl = max(1, int((challenge.expires_at - challenge.created_at).total_seconds()))
        result = await cast(
            Awaitable[object],
            self._redis.eval(
                _CREATE_CHALLENGE,
                2,
                challenge_key,
                idempotency_key,
                "1" if idempotency_key_digest is not None else "0",
                str(challenge.id),
                challenge.identity_subject_hash,
                challenge.code_digest,
                str(challenge.created_at.timestamp()),
                str(challenge.expires_at.timestamp()),
                str(challenge.max_attempts),
                str(ttl),
                str(ttl),
                self._challenge_prefix,
            ),
        )
        if not isinstance(result, list) or len(result) != 2:
            raise RuntimeError("unexpected Redis OTP create result")
        stored_id = UUID(str(result[0]))
        created = str(result[1]) == "1"
        if created:
            return challenge, True
        stored = await self._load(stored_id)
        if stored is None:
            raise RuntimeError("idempotent OTP challenge disappeared")
        return stored, False

    async def verify(
        self,
        challenge_id: UUID,
        code_digest: str,
        now: datetime,
    ) -> OtpVerification:
        result = await cast(
            Awaitable[object],
            self._redis.eval(
                _VERIFY_CHALLENGE,
                1,
                self._challenge_key(challenge_id),
                code_digest,
                str(now.timestamp()),
            ),
        )
        if not isinstance(result, list) or len(result) != 2:
            raise RuntimeError("unexpected Redis OTP verification result")
        status = OtpVerificationStatus(str(result[0]))
        identity_subject_hash = str(result[1]) or None
        return OtpVerification(
            status=status,
            identity_subject_hash=identity_subject_hash,
        )

    async def delete(self, challenge_id: UUID, idempotency_key_digest: str | None) -> None:
        keys = [self._challenge_key(challenge_id)]
        if idempotency_key_digest is not None:
            keys.append(self._idempotency_key(idempotency_key_digest))
        await cast(Awaitable[int], self._redis.delete(*keys))

    async def ping(self) -> None:
        await cast(Awaitable[bool], self._redis.ping())

    async def _load(self, challenge_id: UUID) -> OtpChallenge | None:
        payload = await cast(
            Awaitable[dict[str, str]],
            self._redis.hgetall(self._challenge_key(challenge_id)),
        )
        if not payload:
            return None
        return OtpChallenge(
            id=UUID(payload["id"]),
            identity_subject_hash=payload["identity_subject_hash"],
            code_digest=payload["digest"],
            created_at=datetime.fromtimestamp(float(payload["created_at"]), tz=UTC),
            expires_at=datetime.fromtimestamp(float(payload["expires_at"]), tz=UTC),
            max_attempts=int(payload["max_attempts"]),
        )

    def _challenge_key(self, challenge_id: UUID) -> str:
        return f"{self._challenge_prefix}{challenge_id}"

    def _idempotency_key(self, digest: str) -> str:
        return f"{self._idempotency_prefix}{digest}"
