import secrets
from datetime import datetime

from ordin.modules.ports import OtpCodeGenerator, OtpSender


class SecureOtpCodeGenerator(OtpCodeGenerator):
    def generate(self) -> str:
        return f"{secrets.randbelow(1_000_000):06d}"


class FixedOtpCodeGenerator(OtpCodeGenerator):
    def __init__(self, code: str) -> None:
        if len(code) != 6 or not code.isdigit():
            raise ValueError("development OTP code must contain exactly six digits")
        self._code = code

    def generate(self) -> str:
        return self._code


class DevelopmentOtpSender(OtpSender):
    """Development transport that intentionally never logs or returns OTP values."""

    async def send(self, phone_number: str, code: str, expires_at: datetime) -> None:
        del phone_number, code, expires_at
