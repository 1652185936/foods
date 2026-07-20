import hashlib
import hmac


class HmacDigester:
    def __init__(self, secret: str) -> None:
        self._secret = secret.encode("utf-8")

    def digest(self, value: str) -> str:
        return hmac.new(self._secret, value.encode("utf-8"), hashlib.sha256).hexdigest()
