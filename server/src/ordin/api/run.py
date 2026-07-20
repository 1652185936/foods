import argparse
import asyncio
import selectors
import sys
from ipaddress import ip_address

import uvicorn

from ordin.infrastructure.config import get_settings


def _selector_loop() -> asyncio.AbstractEventLoop:
    return asyncio.SelectorEventLoop(selectors.SelectSelector())


def _is_loopback_host(host: str) -> bool:
    if host.lower() == "localhost":
        return True
    try:
        return ip_address(host).is_loopback
    except ValueError:
        return False


def main() -> None:
    settings = get_settings()
    parser = argparse.ArgumentParser(description="Run the Ordin API with a compatible event loop.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--log-level", default="info")
    parser.add_argument(
        "--allow-insecure-development-host",
        action="store_true",
        help="Explicitly allow development/test OTP mode on a non-loopback interface.",
    )
    arguments = parser.parse_args()
    if (
        settings.environment in {"development", "test"}
        and not _is_loopback_host(arguments.host)
        and not arguments.allow_insecure_development_host
    ):
        parser.error(
            "development/test OTP mode may only listen on a loopback address; "
            "use secure staging/production configuration or pass the explicit unsafe override"
        )
    server = uvicorn.Server(
        uvicorn.Config(
            "ordin.api.main:app",
            host=arguments.host,
            port=arguments.port,
            log_level=arguments.log_level,
            proxy_headers=bool(settings.forwarded_allow_ips.strip()),
            forwarded_allow_ips=settings.forwarded_allow_ips,
        )
    )
    if sys.platform == "win32":
        with asyncio.Runner(loop_factory=_selector_loop) as runner:
            runner.run(server.serve())
        return
    asyncio.run(server.serve())


if __name__ == "__main__":
    main()
