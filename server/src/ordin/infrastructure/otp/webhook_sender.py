from datetime import datetime

from httpx import AsyncClient


class WebhookOtpSender:
    """Deliver an OTP to a private HTTPS relay without coupling to an SMS vendor."""

    def __init__(self, *, client: AsyncClient, url: str, bearer_token: str) -> None:
        self._client = client
        self._url = url
        self._bearer_token = bearer_token

    async def send(self, phone_number: str, code: str, expires_at: datetime) -> None:
        response = await self._client.post(
            self._url,
            headers={"Authorization": f"Bearer {self._bearer_token}"},
            json={
                "phoneNumber": phone_number,
                "code": code,
                "expiresAt": expires_at.isoformat(),
            },
        )
        response.raise_for_status()
