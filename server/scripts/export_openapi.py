import argparse
import json
import sys
from pathlib import Path

from ordin.api.main import app

DEFAULT_OUTPUT = Path(__file__).resolve().parents[2] / "contracts" / "openapi" / "ordin-api-v1.json"


def render_openapi() -> str:
    return json.dumps(app.openapi(), ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export the Ordin OpenAPI contract.")
    parser.add_argument("--check", action="store_true", help="Fail if the contract is stale.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output: Path = args.output.resolve()
    rendered = render_openapi()

    if args.check:
        if not output.exists() or output.read_text(encoding="utf-8") != rendered:
            print(f"OpenAPI contract is stale: {output}", file=sys.stderr)
            return 1
        print(f"OpenAPI contract is current: {output}")
        return 0

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(rendered, encoding="utf-8", newline="\n")
    print(f"Wrote OpenAPI contract: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
