from collections.abc import Awaitable
from typing import cast

from redis.asyncio import Redis

_RATE_LIMIT = """
local count = redis.call('INCR', KEYS[1])
if count == 1 then
  redis.call('EXPIRE', KEYS[1], ARGV[2])
end
local ttl = redis.call('TTL', KEYS[1])
if count > tonumber(ARGV[1]) then
  return ttl
end
return 0
"""


class RedisRateLimiter:
    def __init__(self, redis: Redis) -> None:
        self._redis = redis

    async def hit(self, key: str, *, limit: int, window_seconds: int) -> int | None:
        result = await cast(
            Awaitable[object],
            self._redis.eval(
                _RATE_LIMIT,
                1,
                f"ordin:rate:{key}",
                str(limit),
                str(window_seconds),
            ),
        )
        retry_after = cast(int, result)
        return max(1, retry_after) if retry_after > 0 else None

    async def ping(self) -> None:
        await cast(Awaitable[bool], self._redis.ping())
