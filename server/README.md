# Ordin Server

Minimal FastAPI foundation for the Ordin client.

Run commands from this directory:

```powershell
uv sync --locked --all-groups
uv run --locked uvicorn ordin.api.main:app --reload
uv run --locked ruff format --check .
uv run --locked ruff check .
uv run --locked mypy src tests scripts
uv run --locked pytest
uv run --locked python scripts/export_openapi.py
uv run --locked python scripts/export_openapi.py --check
```

The API health endpoint is available at `GET /api/v1/health`.
